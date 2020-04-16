#compdef pulumi
__pulumi_bash_source() {
	alias shopt=':'
	alias _expand=_bash_expand
	alias _complete=_bash_comp
	emulate -L sh
	setopt kshglob noshglob braceexpand
 	source "$@"
}
 __pulumi_type() {
	# -t is not supported by zsh
	if [ "$1" == "-t" ]; then
		shift
 		# fake Bash 4 to disable "complete -o nospace". Instead
		# "compopt +-o nospace" is used in the code to toggle trailing
		# spaces. We don't support that, but leave trailing spaces on
		# all the time
		if [ "$1" = "__pulumi_compopt" ]; then
			echo builtin
			return 0
		fi
	fi
	type "$@"
}
 __pulumi_compgen() {
	local completions w
	completions=( $(compgen "$@") ) || return $?
 	# filter by given word as prefix
	while [[ "$1" = -* && "$1" != -- ]]; do
		shift
		shift
	done
	if [[ "$1" == -- ]]; then
		shift
	fi
	for w in "${completions[@]}"; do
		if [[ "${w}" = "$1"* ]]; then
			echo "${w}"
		fi
	done
}
 __pulumi_compopt() {
	true # don't do anything. Not supported by bashcompinit in zsh
}
 __pulumi_ltrim_colon_completions()
{
	if [[ "$1" == *:* && "$COMP_WORDBREAKS" == *:* ]]; then
		# Remove colon-word prefix from COMPREPLY items
		local colon_word=${1%${1##*:}}
		local i=${#COMPREPLY[*]}
		while [[ $((--i)) -ge 0 ]]; do
			COMPREPLY[$i]=${COMPREPLY[$i]#"$colon_word"}
		done
	fi
}
 __pulumi_get_comp_words_by_ref() {
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[${COMP_CWORD}-1]}"
	words=("${COMP_WORDS[@]}")
	cword=("${COMP_CWORD[@]}")
}
 __pulumi_filedir() {
	local RET OLD_IFS w qw
 	__debug "_filedir $@ cur=$cur"
	if [[ "$1" = \~* ]]; then
		# somehow does not work. Maybe, zsh does not call this at all
		eval echo "$1"
		return 0
	fi
 	OLD_IFS="$IFS"
	IFS=$'\n'
	if [ "$1" = "-d" ]; then
		shift
		RET=( $(compgen -d) )
	else
		RET=( $(compgen -f) )
	fi
	IFS="$OLD_IFS"
 	IFS="," __debug "RET=${RET[@]} len=${#RET[@]}"
 	for w in ${RET[@]}; do
		if [[ ! "${w}" = "${cur}"* ]]; then
			continue
		fi
		if eval "[[ \"\${w}\" = *.$1 || -d \"\${w}\" ]]"; then
			qw="$(__pulumi_quote "${w}")"
			if [ -d "${w}" ]; then
				COMPREPLY+=("${qw}/")
			else
				COMPREPLY+=("${qw}")
			fi
		fi
	done
}
 __pulumi_quote() {
    if [[ $1 == \'* || $1 == \"* ]]; then
        # Leave out first character
        printf %q "${1:1}"
    else
    	printf %q "$1"
    fi
}
 autoload -U +X bashcompinit && bashcompinit
 # use word boundary patterns for BSD or GNU sed
LWORD='[[:<:]]'
RWORD='[[:>:]]'
if sed --help 2>&1 | grep -q GNU; then
	LWORD='\<'
	RWORD='\>'
fi
 __pulumi_convert_bash_to_zsh() {
	sed \
	-e 's/declare -F/whence -w/' \
	-e 's/_get_comp_words_by_ref "\$@"/_get_comp_words_by_ref "\$*"/' \
	-e 's/local \([a-zA-Z0-9_]*\)=/local \1; \1=/' \
	-e 's/flags+=("\(--.*\)=")/flags+=("\1"); two_word_flags+=("\1")/' \
	-e 's/must_have_one_flag+=("\(--.*\)=")/must_have_one_flag+=("\1")/' \
	-e "s/${LWORD}_filedir${RWORD}/__pulumi_filedir/g" \
	-e "s/${LWORD}_get_comp_words_by_ref${RWORD}/__pulumi_get_comp_words_by_ref/g" \
	-e "s/${LWORD}__ltrim_colon_completions${RWORD}/__pulumi_ltrim_colon_completions/g" \
	-e "s/${LWORD}compgen${RWORD}/__pulumi_compgen/g" \
	-e "s/${LWORD}compopt${RWORD}/__pulumi_compopt/g" \
	-e "s/${LWORD}declare${RWORD}/builtin declare/g" \
	-e "s/\\\$(type${RWORD}/\$(__pulumi_type/g" \
	<<'BASH_COMPLETION_EOF'
# bash completion for pulumi                               -*- shell-script -*-

__pulumi_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__pulumi_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__pulumi_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__pulumi_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__pulumi_handle_reply()
{
    __pulumi_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __pulumi_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __pulumi_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions=("${must_have_one_noun[@]}")
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __pulumi_custom_func >/dev/null; then
			# try command name qualified custom func
			__pulumi_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__pulumi_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__pulumi_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__pulumi_handle_flag()
{
    __pulumi_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __pulumi_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __pulumi_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __pulumi_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __pulumi_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __pulumi_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__pulumi_handle_noun()
{
    __pulumi_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __pulumi_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __pulumi_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__pulumi_handle_command()
{
    __pulumi_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_pulumi_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __pulumi_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__pulumi_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __pulumi_handle_reply
        return
    fi
    __pulumi_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __pulumi_handle_flag
    elif __pulumi_contains_word "${words[c]}" "${commands[@]}"; then
        __pulumi_handle_command
    elif [[ $c -eq 0 ]]; then
        __pulumi_handle_command
    elif __pulumi_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __pulumi_handle_command
        else
            __pulumi_handle_noun
        fi
    else
        __pulumi_handle_noun
    fi
    __pulumi_handle_word
}

_pulumi_cancel()
{
    last_command="pulumi_cancel"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_config_get()
{
    last_command="pulumi_config_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    local_nonpersistent_flags+=("--json")
    flags+=("--path")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_config_refresh()
{
    last_command="pulumi_config_refresh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_config_rm()
{
    last_command="pulumi_config_rm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--path")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_config_set()
{
    last_command="pulumi_config_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--path")
    flags+=("--plaintext")
    flags+=("--secret")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_config()
{
    last_command="pulumi_config"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("refresh")
    commands+=("rm")
    commands+=("set")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--json")
    flags+=("-j")
    local_nonpersistent_flags+=("--json")
    flags+=("--show-secrets")
    local_nonpersistent_flags+=("--show-secrets")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_destroy()
{
    last_command="pulumi_destroy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--diff")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    two_word_flags+=("-p")
    flags+=("--refresh")
    flags+=("-r")
    flags+=("--show-config")
    flags+=("--show-replacement-steps")
    flags+=("--show-sames")
    flags+=("--skip-preview")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--suppress-outputs")
    flags+=("--target=")
    two_word_flags+=("--target")
    two_word_flags+=("-t")
    flags+=("--target-dependents")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_history()
{
    last_command="pulumi_history"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    flags+=("--show-secrets")
    local_nonpersistent_flags+=("--show-secrets")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_login()
{
    last_command="pulumi_login"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloud-url=")
    two_word_flags+=("--cloud-url")
    two_word_flags+=("-c")
    flags+=("--local")
    flags+=("-l")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_logout()
{
    last_command="pulumi_logout"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloud-url=")
    two_word_flags+=("--cloud-url")
    two_word_flags+=("-c")
    flags+=("--local")
    flags+=("-l")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_logs()
{
    last_command="pulumi_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--json")
    flags+=("-j")
    flags+=("--resource=")
    two_word_flags+=("--resource")
    two_word_flags+=("-r")
    flags+=("--since=")
    two_word_flags+=("--since")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_new()
{
    last_command="pulumi_new"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--config-path")
    flags+=("--description=")
    two_word_flags+=("--description")
    two_word_flags+=("-d")
    flags+=("--dir=")
    two_word_flags+=("--dir")
    flags+=("--force")
    flags+=("-f")
    flags+=("--generate-only")
    flags+=("-g")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    flags+=("--offline")
    flags+=("-o")
    flags+=("--secrets-provider=")
    two_word_flags+=("--secrets-provider")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_plugin_install()
{
    last_command="pulumi_plugin_install"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--exact")
    flags+=("--file=")
    two_word_flags+=("--file")
    two_word_flags+=("-f")
    flags+=("--reinstall")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_plugin_ls()
{
    last_command="pulumi_plugin_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    flags+=("--project")
    flags+=("-p")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_plugin_rm()
{
    last_command="pulumi_plugin_rm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_plugin()
{
    last_command="pulumi_plugin"

    command_aliases=()

    commands=()
    commands+=("install")
    commands+=("ls")
    commands+=("rm")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_disable()
{
    last_command="pulumi_policy_disable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--policy-group=")
    two_word_flags+=("--policy-group")
    flags+=("--version=")
    two_word_flags+=("--version")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_enable()
{
    last_command="pulumi_policy_enable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--policy-group=")
    two_word_flags+=("--policy-group")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_group_ls()
{
    last_command="pulumi_policy_group_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_group()
{
    last_command="pulumi_policy_group"

    command_aliases=()

    commands=()
    commands+=("ls")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_ls()
{
    last_command="pulumi_policy_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_new()
{
    last_command="pulumi_policy_new"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dir=")
    two_word_flags+=("--dir")
    flags+=("--force")
    flags+=("-f")
    flags+=("--generate-only")
    flags+=("-g")
    flags+=("--offline")
    flags+=("-o")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_publish()
{
    last_command="pulumi_policy_publish"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_rm()
{
    last_command="pulumi_policy_rm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy_validate-config()
{
    last_command="pulumi_policy_validate-config"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    local_nonpersistent_flags+=("--config=")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_flag+=("--config=")
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_policy()
{
    last_command="pulumi_policy"

    command_aliases=()

    commands=()
    commands+=("disable")
    commands+=("enable")
    commands+=("group")
    commands+=("ls")
    commands+=("new")
    commands+=("publish")
    commands+=("rm")
    commands+=("validate-config")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_preview()
{
    last_command="pulumi_preview"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--config-path")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--diff")
    flags+=("--expect-no-changes")
    flags+=("--json")
    flags+=("-j")
    local_nonpersistent_flags+=("--json")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    two_word_flags+=("-p")
    flags+=("--policy-pack=")
    two_word_flags+=("--policy-pack")
    flags+=("--policy-pack-config=")
    two_word_flags+=("--policy-pack-config")
    flags+=("--refresh")
    flags+=("-r")
    flags+=("--replace=")
    two_word_flags+=("--replace")
    flags+=("--show-config")
    flags+=("--show-reads")
    flags+=("--show-replacement-steps")
    flags+=("--show-sames")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--suppress-outputs")
    flags+=("--target=")
    two_word_flags+=("--target")
    two_word_flags+=("-t")
    flags+=("--target-dependents")
    flags+=("--target-replace=")
    two_word_flags+=("--target-replace")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_refresh()
{
    last_command="pulumi_refresh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--diff")
    flags+=("--expect-no-changes")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    two_word_flags+=("-p")
    flags+=("--show-replacement-steps")
    flags+=("--show-sames")
    flags+=("--skip-preview")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--suppress-outputs")
    flags+=("--target=")
    two_word_flags+=("--target")
    two_word_flags+=("-t")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_export()
{
    last_command="pulumi_stack_export"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("--file")
    flags+=("--version=")
    two_word_flags+=("--version")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_graph()
{
    last_command="pulumi_stack_graph"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dependency-edge-color=")
    two_word_flags+=("--dependency-edge-color")
    flags+=("--ignore-dependency-edges")
    flags+=("--ignore-parent-edges")
    flags+=("--parent-edge-color=")
    two_word_flags+=("--parent-edge-color")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_import()
{
    last_command="pulumi_stack_import"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("--file")
    flags+=("--force")
    flags+=("-f")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_init()
{
    last_command="pulumi_stack_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--secrets-provider=")
    two_word_flags+=("--secrets-provider")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_ls()
{
    last_command="pulumi_stack_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    flags+=("--json")
    flags+=("-j")
    flags+=("--organization=")
    two_word_flags+=("--organization")
    two_word_flags+=("-o")
    flags+=("--project=")
    two_word_flags+=("--project")
    two_word_flags+=("-p")
    flags+=("--tag=")
    two_word_flags+=("--tag")
    two_word_flags+=("-t")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_output()
{
    last_command="pulumi_stack_output"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_rename()
{
    last_command="pulumi_stack_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_rm()
{
    last_command="pulumi_stack_rm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    flags+=("--preserve-config")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_select()
{
    last_command="pulumi_stack_select"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--create")
    flags+=("-c")
    flags+=("--secrets-provider=")
    two_word_flags+=("--secrets-provider")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_tag_get()
{
    last_command="pulumi_stack_tag_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_tag_ls()
{
    last_command="pulumi_stack_tag_ls"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--json")
    flags+=("-j")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_tag_rm()
{
    last_command="pulumi_stack_tag_rm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_tag_set()
{
    last_command="pulumi_stack_tag_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack_tag()
{
    last_command="pulumi_stack_tag"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("ls")
    commands+=("rm")
    commands+=("set")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_stack()
{
    last_command="pulumi_stack"

    command_aliases=()

    commands=()
    commands+=("export")
    commands+=("graph")
    commands+=("import")
    commands+=("init")
    commands+=("ls")
    commands+=("output")
    commands+=("rename")
    commands+=("rm")
    commands+=("select")
    commands+=("tag")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--show-ids")
    flags+=("-i")
    flags+=("--show-secrets")
    flags+=("--show-urns")
    flags+=("-u")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_state_delete()
{
    last_command="pulumi_state_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_state_unprotect()
{
    last_command="pulumi_state_unprotect"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_state()
{
    last_command="pulumi_state"

    command_aliases=()

    commands=()
    commands+=("delete")
    commands+=("unprotect")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_up()
{
    last_command="pulumi_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--config-path")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--diff")
    flags+=("--expect-no-changes")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    two_word_flags+=("-p")
    flags+=("--policy-pack=")
    two_word_flags+=("--policy-pack")
    flags+=("--policy-pack-config=")
    two_word_flags+=("--policy-pack-config")
    flags+=("--refresh")
    flags+=("-r")
    flags+=("--replace=")
    two_word_flags+=("--replace")
    flags+=("--secrets-provider=")
    two_word_flags+=("--secrets-provider")
    flags+=("--show-config")
    flags+=("--show-reads")
    flags+=("--show-replacement-steps")
    flags+=("--show-sames")
    flags+=("--skip-preview")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--suppress-outputs")
    flags+=("--target=")
    two_word_flags+=("--target")
    two_word_flags+=("-t")
    flags+=("--target-dependents")
    flags+=("--target-replace=")
    two_word_flags+=("--target-replace")
    flags+=("--yes")
    flags+=("-y")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_version()
{
    last_command="pulumi_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_watch()
{
    last_command="pulumi_watch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    flags+=("--config-path")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--message=")
    two_word_flags+=("--message")
    two_word_flags+=("-m")
    flags+=("--parallel=")
    two_word_flags+=("--parallel")
    two_word_flags+=("-p")
    flags+=("--policy-pack=")
    two_word_flags+=("--policy-pack")
    flags+=("--policy-pack-config=")
    two_word_flags+=("--policy-pack-config")
    flags+=("--refresh")
    flags+=("-r")
    flags+=("--secrets-provider=")
    two_word_flags+=("--secrets-provider")
    flags+=("--show-config")
    flags+=("--show-replacement-steps")
    flags+=("--show-sames")
    flags+=("--stack=")
    two_word_flags+=("--stack")
    two_word_flags+=("-s")
    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_whoami()
{
    last_command="pulumi_whoami"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pulumi_root_command()
{
    last_command="pulumi"

    command_aliases=()

    commands=()
    commands+=("cancel")
    commands+=("config")
    commands+=("destroy")
    commands+=("history")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("hist")
        aliashash["hist"]="history"
    fi
    commands+=("login")
    commands+=("logout")
    commands+=("logs")
    commands+=("new")
    commands+=("plugin")
    commands+=("policy")
    commands+=("preview")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("pre")
        aliashash["pre"]="preview"
    fi
    commands+=("refresh")
    commands+=("stack")
    commands+=("state")
    commands+=("up")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("update")
        aliashash["update"]="up"
    fi
    commands+=("version")
    commands+=("watch")
    commands+=("whoami")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--color=")
    two_word_flags+=("--color")
    flags+=("--cwd=")
    two_word_flags+=("--cwd")
    two_word_flags+=("-C")
    flags+=("--disable-integrity-checking")
    flags+=("--emoji")
    flags+=("-e")
    flags+=("--logflow")
    flags+=("--logtostderr")
    flags+=("--non-interactive")
    flags+=("--profiling=")
    two_word_flags+=("--profiling")
    flags+=("--tracing=")
    two_word_flags+=("--tracing")
    flags+=("--verbose=")
    two_word_flags+=("--verbose")
    two_word_flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_pulumi()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __pulumi_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("pulumi")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __pulumi_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_pulumi pulumi
else
    complete -o default -o nospace -F __start_pulumi pulumi
fi

# ex: ts=4 sw=4 et filetype=sh

BASH_COMPLETION_EOF
}
__pulumi_bash_source <(__pulumi_convert_bash_to_zsh)
_complete pulumi 2>/dev/null
