# Pulumi
This plugin provides completion support for [pulumi](https://www.pulumi.com/) and to deploy and manage Pulumi stacks and resources and display them in the prompt.

To use it, add `pulumi` to the plugins array in your .zshrc file.

```zsh
plugins=(... pulumi)
```

## Plugin Commands

- `pn`: creates new pulumi project & stack
- `psl`: lists all pulumi stacks