/*

# Firmware for i.MX

Proprietary / closed-source NXP firmware for i.MX(8) boards.
This package just downloads the prebuilt firmware and extracts it.

To do the extraction without prompt, the `--auto-accept` license/EULA flag has to be passed; the package is therefore marked as `unfree`.
The license (currently) is [LA_OPT_NXP_Software_License](https://www.nxp.com/docs/en/disclaimer/LA_OPT_NXP_SW.html) v35, as stated in the package output's `COPYING` file.
To use the package, acceptance of the license must be indicated, e.g. by setting (in the host config):
```nix
{ nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "firmware-imx" ]; }
```


## Implementation

```nix
#*/# end of MarkDown, beginning of NixPkgs overlay:
dirname: inputs: final: prev: let
    inherit (final) pkgs; lib = inputs.self.lib.__internal__;
in {

    firmware-imx = pkgs.stdenv.mkDerivation rec {
        meta = { license = lib.licenses.unfree; description = "Proprietary NXP firmware blobs for i.MX(8) boards."; };
        pname = "firmware-imx"; version = "8.15"; # no idea how to query for the version other than trying ever higher numbers
        src = pkgs.fetchurl {
            url = "https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-${version}.bin";
            hash = "sha256-k34ZZHa46VtLfyUBoUyDJtigZJ+KP5IotyNzdwoI3rM=";
        }; dontUnpack = true;
        installPhase = ''
            ${pkgs.bash}/bin/bash $src --auto-accept --force
            mv firmware-imx-${version} $out
        '';
        dontStrip = true;
    };
}
