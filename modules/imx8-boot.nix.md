/*

# i.MX(8) Boot-y Things

The i.MX's SOC boot process requires an image with multiple stages of boot loaders / initialization code for different SOC components to be placed in a pre-defined location on the boot medium.
This Builds such an image for microSD cards and sets the instructions to place it on the card('s image) during system installation.
The final bootloader stage in the image is U-boot, and that is (by default) configured to read and process the `extlinux.conf` from the boot partition, so from there things can be handled via the `boot.loader.generic-extlinux-compatible.*` config options.
By default the image gets built from sources, except for the `firmware-imx`, which NXP only provides as proprietary blob. Consequently, `firmware-imx` needs to be allowed as unfree software.

U-boot is (usually) configured to only output to the UART console.
(At least) with the full-sized EVK boards, that console can be accessed by connecting the board's "debug" micro-USB to a different host, and (assuming there were no `/dev/ttyUSB*` before) running:
```bash
nix-shell -p tio --run 'tio /dev/ttyUSB2' # (tio uses the correct settings by default)
```

## Notice

The »linux-imx_v8« kernel as it is now builds some things that NixOS expects to exist as modules either not at all, or not as a module. They thus have to be un-included from the host's config.
Most are excluded by setting `boot.initrd.includeDefaultModules = false` (though some hosts might need individual ones of the default modules added back explicitly).
The `tasks/swraid.nix` module in `nixpkgs` unfortunately unconditionally includes the `raid0` module, which also does not exist. Removing modules can not be done conditionally (on this module being enabled).

If there is a problem with the `raid0` kernel module, exclude the `tasks/swraid.nix` NixOS module form the host config in question:
```nix
{
    imports = [ (lib.wip.makeNixpkgsModuleConfigOptional (specialArgs) "tasks/swraid.nix") ]; # This can be set globally for all hosts, but may only be defined once per config.
    disableModule."tasks/swraid.nix" = true; # And then the module can be disabled per host.
} // { # OR
    imports = [ { disabledModules = [ "tasks/swraid.nix" ]; } ]; # Add this import only for hosts where the module is to be removed (but consider that this also removes any option definitions made by the module, which may break evaluation elsewhere).
}
```


## Implementation

```nix
#*/# end of MarkDown, beginning of NixOS module:
dirname: inputs: specialArgs@{ config, pkgs, lib, ... }: let inherit (inputs.self) lib; in let
    cfg = config.nxp.imx8-boot;
in {

    options.nxp = { imx8-boot = {
        enable = lib.mkEnableOption "the bootloader for an i.MX 8 board";
        soc = lib.mkOption { description = "The target SOC name, in the form that »mkimage_imx8« / »imx-mkimage« expects it."; type = lib.types.nullOr lib.types.str; default = null; example = "iMX8MP"; };
        boot-image = lib.mkOption { description = "Path to the complete boot image. Can be set explicitly to use a prebuilt image, if the one built from sources does not work or the building fails/takes too long."; type = lib.types.path; };
        uboot.package = lib.mkOption { description = "U-boot package as result of »pkgs.uboot-with-mmc-env« used in the ».boot-image«."; type = lib.types.package; };
        uboot.envVars = lib.mkOption { description = "U-boot env vars that get merged over »uboot-imx.defaultEnv«. To remove a variable, set its value to »null«."; type = lib.types.attrsOf lib.types.str; default = { }; };
        uboot.envSize = lib.mkOption { description = "The env size that ».boot-image« is configured to use."; type = lib.types.int; default = 16384; };
    }; };

    config = lib.mkIf cfg.enable (lib.mkMerge [ (let

        default-uboot = pkgs.uboot-with-mmc-env {
            base = pkgs.uboot-imx.override { platform = lib.toLower cfg.soc; };
            envSize = cfg.uboot.envSize; defaultEnv = cfg.uboot.envVars;
        };

        default-boot-image = let # This works for »SOC=iMX8MP«; other boards may need to copy in different files.
            targetPkgs = if config.nixpkgs.crossSystem == null || config.nixpkgs.crossSystem.system == config.nixpkgs.localSystem.system then specialArgs.pkgs else import inputs.nixpkgs { inherit (config.nixpkgs) config overlays; localSystem.system = config.nixpkgs.crossSystem.system; crossSystem = null; };
            SOC = cfg.soc; SOC_DIR = if lib.wip.startsWith "iMX8M" SOC then "iMX8M" else SOC;
            LPDDR_FW_VERSION = "_202006"; # This must match the files in »firmware-imx«.
        in pkgs.stdenv.mkDerivation rec {
            # Found this when I was just about done. Nice to know someone else came to the same solution: https://gist.github.com/KunYi/6ababe7ca5f00eb87a216eb52f4bdc3b
            # Also: https://variwiki.com/index.php?title=Yocto_Build_U-Boot&release=RELEASE_DUNFELL_V1.1_DART-MX8M-MINI
            name = "${lib.toLower SOC}-evk-boot-image"; src = targetPkgs.mkimage_imx8; nativeBuildInputs = [ pkgs.dtc pkgs.gcc ];
            inherit SOC SOC_DIR LPDDR_FW_VERSION;
            patchPhase = ''
                cp --no-preserve=mode -v -T ${cfg.uboot.package}/u-boot-spl.bin ./${SOC_DIR}/u-boot-spl.bin
                cp --no-preserve=mode -v -T ${cfg.uboot.package}/u-boot-nodtb.bin ./${SOC_DIR}/u-boot-nodtb.bin
                cp --no-preserve=mode -v -T ${cfg.uboot.package}/${lib.toLower SOC}-evk.dtb ./${SOC_DIR}/${lib.toLower SOC}-evk.dtb
                cp --no-preserve=mode -v ${pkgs.firmware-imx}/firmware/ddr/synopsys/lpddr4_pmu_train_{1d_dmem,1d_imem,2d_dmem,2d_imem}${LPDDR_FW_VERSION}.bin ./${SOC_DIR}/
                cp --no-preserve=mode -v -T ${pkgs.imx-atf.override { platform = lib.toLower SOC; }}/bl31.bin ./${SOC_DIR}/bl31.bin
            '';
            buildPhase = ''make SOC=${SOC} flash_evk''; # or something more specific, like flash_lpddr4_ddr4_evk
            #installPhase = ''wd=$(pwd) ; cd .. ; mv $wd $out ; cd $out ; cp ./${SOC_DIR}/flash.bin $out/'';
            installPhase = ''mkdir -p $out/ ; cp ./${SOC_DIR}/flash.bin $out/'';
            dontStrip = true;
        };

        # if=.../flash.bin ; dd bs=1024 seek=32 count=$(( $(du -b $if | cut -f1) / 1024 + 1 )) of=/dev/sdd if=$if
        # dd bs=1024 count=16000 if=/dev/sdc | strings -n 8 -t x
        # dd bs=1024 skip=32    count=4 if=/dev/sdc         | xxd -c 64
        # dd bs=1024            count=4 if=/dev/sdc127      | xxd -c 64
        # nix-shell -p busybox --run 'dd bs=1024                    if=/dev/mmcblk1p128 | xxd -c 64'
        # nix-shell -p busybox --run 'dd bs=1024 skip=4096  count=8 if=/dev/mmcblk1     | xxd -c 64'

        hash = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);

    in {

        ## Firmware:
        # Create partitions for the firmware+bootloader image and the bootloader config. These need to be in specific places, thus need to be created early (high order) while that space is still free, but partition index 1 should remain available for »/boot«:
        wip.fs.disks.partitions."bootloader-${hash}" = { type = "ef02"; position = "64"; size = lib.mkDefault (toString (cfg.uboot.package.envOffset / 512 - 64)); index = lib.mkDefault 127; order = lib.mkDefault 2000; alignment = 1; }; # The boot image needs to start at position 32K (64×512b) and is about 2MB in size.
        wip.fs.disks.partitions."uboot-env-${hash}" = { type = "ef02"; position = toString (cfg.uboot.package.envOffset / 512); size = toString (cfg.uboot.package.envSize / 512); index = lib.mkDefault 128; order = lib.mkDefault 2000; alignment = 1; }; # The position and size of the U-boot env are compiled into U-boot.
        wip.fs.disks.postFormatCommands = ''
            ${if (config.wip.fs.disks.partitions."bootloader-${hash}" or null) != null then ''
                cat /dev/null         >/dev/disk/by-partlabel/bootloader-${hash}
                cat ${cfg.boot-image} >/dev/disk/by-partlabel/bootloader-${hash}
            '' else ''
                function get-parent-disk {( set -eu ; # 1: partition
                    partition=$( realpath "$1" ) ; shopt -s extglob
                    if [[ $partition == /dev/sd* ]] ; then echo "''${partition%%+([0-9])}" ; else echo "''${partition%%p+([0-9])}" ; fi
                )}
                dd status=none conv=notrunc bs=32768 seek=1 of=$( get-parent-disk /dev/disk/by-partlabel/uboot-env-${hash} ) if=${cfg.boot-image}
            ''}
            cat ${cfg.uboot.package.mkEnv { }} >/dev/disk/by-partlabel/uboot-env-${hash}
        '';
        environment.etc."fw_env.config".text = lib.mkDefault "/dev/disk/by-partlabel/uboot-env-${hash} 0x0 0x${lib.concatStrings (map toString (lib.toBaseDigits 16 cfg.uboot.package.envSize))}\n";
        nxp.imx8-boot.boot-image = lib.mkOptionDefault "${default-boot-image}/flash.bin";
        nxp.imx8-boot.uboot.package = lib.mkOptionDefault default-uboot;
        nxp.imx8-boot.uboot.envVars = {
            # This works for an imx8mp:
            #           1MB  =                        0x100000
            # Defaults of the imx8mp for reference:
            # kernel_addr_r  =                     "0x40480000";
            # fdt_addr_r     =                     "0x43000000"; # +43MB
            # initrd_addr    =                     "0x43800000"; # +08MB
            # Make more room for larger images:
            scriptaddr       = lib.mkOptionDefault "0x40480000";
            kernel_addr_r    = lib.mkOptionDefault "0x41000000";
            fdt_addr_r       = lib.mkOptionDefault "0x47000000"; # +96MB
            ramdisk_addr_r   = lib.mkOptionDefault "0x49000000"; # +32MB
            fdtfile = "freescale/${lib.toLower cfg.soc}-evk.dtb";
            bootcmd = "sysboot mmc 1:1 fat \${scriptaddr} /extlinux/extlinux.conf"; # (only) process extlinux.conf from eMMC/microSD
            /* To run these in an uboot prompt:
            setenv kernel_addr_r  0x41000000
            setenv fdt_addr_r     0x47000000
            setenv ramdisk_addr_r 0x49000000
            setenv fdtfile freescale/imx8mp-evk.dtb
            setenv bootcmd sysboot mmc 1:1 fat 0x40480000 /extlinux/extlinux.conf
            boot */
        };

        ## Bootloader:
        boot.loader.generic-extlinux-compatible.enable = true; boot.loader.grub.enable = false;
        wip.fs.boot.enable = true; wip.fs.boot.createMbrPart = true;

        ## Kernel:
        hardware.deviceTree.filter = lib.mkDefault "*${lib.toLower cfg.soc}*.dtb"; # (there is even a »imx8mp-evk.dtb« with the default kernel, but it has no display output)
        boot.kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor (pkgs.linux-imx_v8));

        boot.initrd.includeDefaultModules = false; # (might need some of these back)
        boot.initrd.availableKernelModules = [ "ext2" "ext4" ];

        # Alternative kernel build:
        #hardware.deviceTree.kernelPackage = pkgs.linux-imx; # these boot the default kernel just fine, but without display output
        #boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux-imx);


    }) ]);

}
