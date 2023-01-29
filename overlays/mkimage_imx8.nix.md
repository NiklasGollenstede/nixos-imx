/*

# Make (boot) Image for i.MX

This is the tool to create (SOC-specific) i.MX boot images.
The sources are downloaded and the builder tool is pre-compiled to speed up image builds for individual board.
As such, this is not an installable package but rather a prepared input for building the actual boot image per SOC.


## Example

The creation of the boot images is a bit of a mess and requires moving files into the source tree before calling make.
Which exact files those are depends on the SOC.

Also, `mkimage_imx8` does not cross-compile. So when cross-compiling the system, this package has to be explicitly non-cross-compiled (not pretty, and requires [qemu binfmt registration](../README.md#building), but at least it works).

```nix
{ boot-image = let
    SOC = cfg.soc; SOC_DIR = if lib.wip.startsWith "iMX8M" SOC then "iMX8M" else SOC;
    LPDDR_FW_VERSION = "_202006"; # This must match the files in »firmware-imx«.
    targetPkgs = if config.nixpkgs.crossSystem == null || config.nixpkgs.crossSystem.system == config.nixpkgs.localSystem.system then pkgs else import pkgs.path { inherit (config.nixpkgs) config overlays; localSystem.system = config.nixpkgs.crossSystem.system; crossSystem = null; }; # (don't try to cross-compile »mkimage_imx8«)
in pkgs.stdenv.mkDerivation rec {
    name = "${lib.toLower SOC}-evk-boot-image"; src = targetPkgs.mkimage_imx8; nativeBuildInputs = [ pkgs.dtc pkgs.gcc targetPkgs.binutils ]; # (using »targetPkgs.binutils« here is unclean, but it works ...)
    inherit SOC SOC_DIR LPDDR_FW_VERSION;
    patchPhase = ''
        cp -v ${uboot}/{...} ./${SOC_DIR}/
        cp -v ${pkgs.firmware-imx}/.../{...}${LPDDR_FW_VERSION}.bin ./${SOC_DIR}/
        cp -v ${pkgs.imx-atf.override { platform = lib.toLower SOC; }}/bl31.bin ./${SOC_DIR}/
    '';
    buildPhase = ''make SOC=${SOC} flash_evk''; # or something more specific
    installPhase = ''mkdir -p $out/ ; cp ./${SOC_DIR}/flash.bin $out/'';
    dontStrip = true;
}; }
```


## Implementation

```nix
#*/# end of MarkDown, beginning of NixPkgs overlay:
dirname: inputs: final: prev: let
    inherit (final) pkgs; inherit (inputs.self) lib;
in {

    mkimage_imx8 = pkgs.stdenv.mkDerivation rec {
        meta = { license = lib.licenses.gpl2; description = "Boot image builder for i.MX8 boards."; };
        pname = "mkimage_imx8"; version = "lf-5.15.5-1.0.0"; commit = "22346a32a88aa752d4bad8f2ed1eb641e18849dc";
        src = pkgs.fetchgit {
            url = "https://source.codeaurora.org/external/imx/imx-mkimage"; rev = commit;
            sha256 = "sha256-p0KyXpONeuLxt2f6k4cSiBchbPX4WUvbT63Mn5txfX4=";
        };
        patchPhase = ''substituteInPlace Makefile --replace "git rev-parse --short=8 HEAD" "echo ${builtins.substring 0 8 commit}"'';
        buildInputs = [ pkgs.glibc.static pkgs.zlib pkgs.zlib.static ];
        buildPhase = ''
            make bin ; make -C iMX8M -f soc.mak mkimage_imx8
            cp -v ${pkgs.ubootTools}/bin/mkimage ./iMX8M/mkimage_uboot
        '';
        installPhase = ''wd=$(pwd) ; cd .. ; mv $wd $out ; cd $out'';
        dontStrip = true;
    };
}
