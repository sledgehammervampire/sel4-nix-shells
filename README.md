# sel4-nix-shells
## Usage
First, make sure [Nix flakes are
enabled](https://nixos.wiki/wiki/Flakes#:~:text=Installing%20flakes). Then type
```
nix develop $REPO_PATH#$SHELL_NAME
```
into a shell, where `$REPO_PATH` is the path to this repo, and `$SHELL_NAME` is
one of `sel4`, `camkes`, `l4v`, or `cp`.