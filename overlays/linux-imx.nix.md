/*

# Linux Kernel for i.MX (8)

NXP's fork of the Linux Kernel, built for NixOS.


## Implementation

```nix
#*/# end of MarkDown, beginning of NixPkgs overlay:
dirname: inputs: final: prev: let
    inherit (final) pkgs; lib = inputs.self.lib.__internal__;
in {

    linux-imx_v8 = pkgs.callPackage (args@{

        # Override this for a different CPU generations:
        configfilePath ? "arch/arm64/configs/imx_v8_defconfig", # imx_v6/v7_defconfig is in arch/arm/configs

        # Override these to update:
        version ? "5.15.5",
        rev ? "lf-${version}-1.0.0", # must use tags created by NXP (and not ones merged from upstream?)
        hash ? "sha256-iTagiSjU65V7ZpKQa4IMZeRp8lTTcRNohJ2S2hgaETs=",

        lib, stdenv, ... # Just forward whatever else the system's config passes.
    }: (pkgs.linuxKernel.manualConfig (args // rec {

        inherit version; src = pkgs.applyPatches { name = "linux-imx-patched"; src = pkgs.fetchgit {
            url = "https://github.com/nxp-imx/linux-imx"; inherit rev hash;
        }; patches = [
            ../patches/linux-imx-extend-config.patch # Enable all features that NixOS wants.
            ../patches/linux-imx-remove-flags.patch
        ]; }; # (apply patches here, so that the defconfig file can be patched)

        configfile = "${src}/${configfilePath}";

        allowImportFromDerivation = true;

    })).overrideAttrs (old: {
        hardeningDisable = (old.hardeningDisable or [ ]) ++ [ "relro" ]; # suppress warning that this isn't supported (for aarch64)
    })) { };

    # NixOS' "everything as module" strategy also works on the patched sources and »imx_v8_defconfig«, but it's a bit of a mess:
    linux-imx = pkgs.callPackage (args@{
        stdenv, lib, buildPackages, fetchgit, perl,
        buildLinux, defconfig ? "imx_v8_defconfig",
    ... }: (let
        modDirVersion = "5.15.5";
        tag = "lf-${modDirVersion}-1.0.0"; # must use tags created by NXP (and not ones merged from upstream?)
        src = fetchgit {
            url = "https://github.com/nxp-imx/linux-imx"; rev = tag;
            hash = "sha256-iTagiSjU65V7ZpKQa4IMZeRp8lTTcRNohJ2S2hgaETs=";
        };
    in lib.overrideDerivation (buildLinux (args // { # The structure of this was taken from <https://github.com/NixOS/nixpkgs/blob/nixos-21.11/pkgs/os-specific/linux/kernel/linux-rpi.nix>.
        version = "${modDirVersion}"; inherit src modDirVersion defconfig;
        kernelPatches = (args.kernelPatches or [ ]) ++ [ {
            patch = ../patches/linux-imx-fix-redefine.patch;
            name = "without request_secure_key redefinition";
        } {
            patch = ../patches/linux-imx-remove-flags.patch;
            name = "without missing AFLAGS";
        } {
            patch = ../patches/linux-imx-fix-meta.patch;
            name = "fixed module metadata license";
        } ];

        features = { efiBootStub = false; } // (args.features or { });

        structuredExtraConfig = {
            #SECURE_KEYS = lib.kernel.no; # else: »error: redefinition of 'request_secure_key'« TODO: this didn't help, see the »linux-imx-fix-redefine.patch«.
            FB_MXS_SII902X = lib.kernel.no; # has a broken include on »<asm/mach-types.h>«
            FB_MXC_EINK_PANEL = lib.kernel.no; FB_MXC_EINK_V2_PANEL = lib.kernel.no; # undeclared functions and incorrect pointers passed
            SND_SOC_IMX_HDMI_DMA = lib.kernel.no; # »sound/soc/fsl/Makefile« uses some arm 32bit specific compiler optimizations -> we don't want this on aarch64 boards at all? TODO: This is still »y« in the resulting config (after »make ... Image vmlinux modules dtbs«)!
            REGULATOR_PF1550_RPMSG = lib.kernel.no;
            MFD_MAX17135 = lib.kernel.no;
            MXC_CAMERA_OV5647_MIPI = lib.kernel.no;
            MXC_TVIN_ADV7180 = lib.kernel.no; VIDEO_V4L2_MXC_INT_DEVICE = lib.kernel.no; # (just in case)
            VIDEO_MXC_PXP_V4L2 = lib.kernel.no;
            MHDP_HDMIRX = lib.kernel.no; # »'FW_ACTION_HOTPLUG' undeclared«
            MXC_SIMv2 = lib.kernel.no; # »-Wpointer-to-int-cast«
            MOST = lib.kernel.no; # no error, but last thing that was compiled; may be red herring
            TLS = lib.mkForce lib.kernel.no; # with »CRYPTO_TLS«: »the following would cause module name conflict: crypto/tls.ko net/tls/tls.ko«
            # FB_MXC_DISP_FRAMEWORK can't be set to no, thus »linux-imx-fix-meta.patch[]
            FB_MXC_TRULY_PANEL_TFT3P5581E = lib.kernel.no; FB_MXC_TRULY_WVGA_SYNC_PANEL = lib.kernel.no; FB_MXC_RK_PANEL_RK055AHD042 = lib.kernel.no; FB_MXC_RK_PANEL_RK055IQH042 = lib.kernel.no; # missing license metadata
            FB_MXC_MIPI_DSI_NORTHWEST = lib.kernel.no; FB_MXC_ADV7535 = lib.kernel.no; FB_MXC_MIPI_DSI_SAMSUNG = lib.kernel.no; ENCRYPTED_KEYS = lib.kernel.no; SENSORS_MAX17135 = lib.kernel.no; SND_SOC_FSL_HDMI = lib.kernel.no; # missing symbols
        };

        extraMeta = {
            platforms = with lib.platforms; [ arm aarch64 ];
            hydraPlatforms = [ "aarch64-linux" ];
        };
    } // (args.argsOverride or { }))) (old: {
    }))) { };

}
