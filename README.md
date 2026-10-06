# trivalent-nix
an **unofficial** nix flake for [trivalent](https://github.com/secureblue/Trivalent)  


## Installation
add trivalent to inputs:
```nix
inputs.trivalent-nix = "git+https://codeberg.org/quixaq/trivalent-nix";
```
add module to nixosSystem
```nix
outputs = { nixpkgs, trivalent-nix, ... }: {
  nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
    modules = [
      ./configuration.nix
      trivalent-nix.nixosModules.default
    ];
  };
};
```
