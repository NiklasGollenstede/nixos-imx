/*

# U-Boot for i.MX (8)

NXP's fork of the U-Boot, built in Nix for i.MX8.


## Example

```nix
let soc = "iMX8MP"; in
pkgs.uboot-imx.override { platform = lib.toLower soc; }
```


## Implementation

```nix
#*/# end of MarkDown, beginning of NixPkgs overlay:
dirname: inputs: final: prev: let
    inherit (final) pkgs; inherit (inputs.self) lib;
in {

    uboot-imx = pkgs.callPackage ({
        pkgs, lib, # (provided by callPackage)

        # The target SoC, e.g »imx8mp«:
        platform ? null, # needs to be overridden explicitly
        platformSuffix ? "_evk",

    }: (pkgs.buildUBoot (let
        envTxt = env: pkgs.writeText "uboot-env.txt" "${lib.concatStrings (lib.mapAttrsToList (k: v: if v == null then "" else "${k}=${toString v}\n") env)}";
    in rec {
        version = "lf-5.15.5-1.0.0"; commit = "f7b43f8b4c1e4e3ee6c6ff2fe9c61b2092e8b96b"; # (from tag)
        src = pkgs.fetchgit {
            url = "https://source.codeaurora.org/external/imx/uboot-imx"; rev = commit;
            hash = "sha256-wiUTdCMuRPPR8jIaPOOomyEb3F6JHj1ZFwkeAguGl78=";
        }; patches = [ ];
        defconfig = "${platform}${platformSuffix}_defconfig";
        extraMeta.platforms = [ "aarch64-linux" ];
        filesToInstall = [ "u-boot-nodtb.bin" "spl/u-boot-spl.bin" "arch/arm/dts/${platform}-evk.dtb" ".config" "include/env_default.h" ];
    })).overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.perl ];
    })) { };

}
