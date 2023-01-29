{ description = (
    "i.MX (8) specific Linux kernel, u-boot bootloader, firmware, etc packaged in Nix for NixOS"
    /**
     * This flake file defines the main inputs (all except for some files/archives fetched by hardcoded hash) and exports almost all usable results.
     * It should always pass »nix flake check« and »nix flake show --allow-import-from-derivation«, which means inputs and outputs comply with the flake convention.
     */
); inputs = {

    # To update »./flake.lock«: $ nix flake update
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-22.11"; };
    wiplib = { url = "github:NiklasGollenstede/nix-wiplib"; inputs.nixpkgs.follows = "nixpkgs"; };
    #nixos-imx = { url = "github:NiklasGollenstede/nixos-imx"; inputs.nixpkgs.follows = "nixpkgs"; inputs.wiplib.follows = "wiplib"; }; # (uncomment this when reusing this file in your own repo)

}; outputs = inputs@{ self, wiplib, ... }: wiplib.lib.wip.importRepo inputs ./. (repo@{ overlays, ... }: let
    inherit (wiplib) lib;
in [ # Run »nix flake show --allow-import-from-derivation« to see what this merges to:
    repo { inherit lib; } # => lib overlays.* nixosModules.*
    (lib.wip.mkSystemsFlake { inherit inputs; }) # => nixosConfigurations.* packages.*-linux.all-systems
    (lib.wip.mkSystemsFlake { inherit inputs; localSystem = "x86_64-linux"; renameOutputs = key: "x64:${key}"; }) # => nixosConfigurations.x64:* packages.*-linux.x64:all-systems
    (lib.wip.forEachSystem [ "aarch64-linux" "x86_64-linux" ] (localSystem: {
        packages = lib.wip.getModifiedPackages (lib.wip.importPkgs inputs { system = localSystem; }) overlays;
        defaultPackage = self.packages.${localSystem}.all-systems;
    }))
]); }
