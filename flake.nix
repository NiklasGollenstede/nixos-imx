{ description = (
    "i.MX (8) specific Linux kernel, u-boot bootloader, firmware, etc packaged in Nix for NixOS"
    /**
     * This flake file defines the main inputs (all except for some files/archives fetched by hardcoded hash) and exports almost all usable results.
     * It should always pass »nix flake check« and »nix flake show --allow-import-from-derivation«, which means inputs and outputs comply with the flake convention.
     */
); inputs = {

    # To update »./flake.lock«: $ nix flake update
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-23.05"; };
    functions = { url = "github:NiklasGollenstede/nix-functions"; inputs.nixpkgs.follows = "nixpkgs"; };
    installer = { url = "github:NiklasGollenstede/nixos-installer"; inputs.nixpkgs.follows = "nixpkgs"; inputs.functions.follows = "functions"; };
    wiplib = { url = "github:NiklasGollenstede/nix-wiplib"; inputs.nixpkgs.follows = "nixpkgs"; inputs.functions.follows = "functions"; inputs.installer.follows = "installer"; };
    #nixos-imx = { url = "github:NiklasGollenstede/nixos-imx"; inputs.nixpkgs.follows = "nixpkgs"; inputs.wiplib.follows = "wiplib"; }; # (uncomment this when reusing this file in your own repo)

}; outputs = inputs@{ self, ... }: inputs.functions.lib.importRepo inputs ./. (repo@{ overlays, ... }: let
    lib = inputs.nixpkgs.lib // { fun = inputs.functions.lib; inst = inputs.installer.lib; wip = inputs.wiplib.lib; };
in [ # Run »nix flake show --allow-import-from-derivation« to see what this merges to:
    repo { lib.__internal__ = lib; } # => lib overlays.* nixosModules.*
    (lib.inst.mkSystemsFlake { inherit inputs; }) # => nixosConfigurations.* packages.*-linux.all-systems
    (lib.inst.mkSystemsFlake { inherit inputs; buildPlatform = "x86_64-linux"; renameOutputs = key: "x64:${key}"; }) # => nixosConfigurations.x64:* packages.*-linux.x64:all-systems
    (lib.fun.forEachSystem [ "aarch64-linux" "x86_64-linux" ] (localSystem: {
        packages = lib.fun.getModifiedPackages (lib.fun.importPkgs inputs { system = localSystem; }) overlays;
        defaultPackage = self.packages.${localSystem}.all-systems;
    }))
]); }
