/*

# ARM Trusted Firmware for i.MX

Firmware for the "secure world" / trust zone of ARM application processors, as forked by NXP for its i.MX processors.


## Example

```nix
let soc = "iMX8MP"; in
pkgs.imx-atf.override { platform = lib.toLower soc; }
```


## Implementation

```nix
#*/# end of MarkDown, beginning of NixPkgs overlay:
dirname: inputs: final: prev: let
    inherit (final) pkgs; inherit (inputs.self) lib;
in {

    imx-atf = pkgs.callPackage ({
        pkgs, lib,
        platform ? "", # needs to be overridden explicitly
    }: pkgs.stdenv.mkDerivation rec {
        meta = { license = lib.licenses.mit; description = "ARM Trusted Firmware for the i.MX ${platform}"; };
        pname = "arm-trusted-firmware-${platform}"; version = "2.6"; # from »./Makefile«
        src = (pkgs.fetchgit {
            url = "https://source.codeaurora.org/external/imx/imx-atf";
            rev = "f78cb61a11da3d965be809ebf8b592a8c33f6473"; # from branch »github.com/master«
            hash = "sha256-VnNWfA6ZYXDrYVEmvaU84eC9K5p/nayfwERjyhf48dQ=";
        });
        nativeBuildInputs = [ pkgs.gcc ]; # (required for cross-compiling ...)
        buildPhase = ''platform=${platform} ; make PLAT=''${platform:?} bl31'';
        installPhase = ''mkdir -p $out/ ; cp -v ./build/${platform}/release/bl31.bin $out/'';
        dontStrip = true;
    }) { };

}
