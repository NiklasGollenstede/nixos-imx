/*

# NixOS on i.MX Example

Example (and test) host configuration for running NixOS on an i.MX 8M Plus evaluation board (via microSD).


## Installation

To prepare the microSD `/dev/sdX`, as `sudo` user with `nix` installed, run:
```bash
 nix run '.#imx8mp' -- sudo install-system /dev/sdX
```
Or for the version cross-compiled from `x64`, run:
```bash
 nix run '.#x64:imx8mp' -- sudo install-system /dev/sdX
```
Then put the card into the board, and use the switch to re-enable power.


## Implementation

```nix
#*/# end of MarkDown, beginning of NixOS config flake input:
dirname: inputs: specialArgs@{ config, pkgs, lib, name, ... }: let lib = inputs.self.lib.__internal__; in let
    hash = builtins.substring 0 8 (builtins.hashString "sha256" name);
in { imports = [ ({ ## Hardware

    nixpkgs.hostPlatform = "aarch64-linux"; system.stateVersion = "22.05";

    # Booting:
    nxp.imx8-boot.enable = true; nxp.imx8-boot.soc = "iMX8MP";
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "firmware-imx" ];

    # Disk setup:
    setup.disks.devices.primary.size = 31657558016; # If this mismatches, use whatever the installer says.
    setup.temproot = { enable = true; temp.type = "tmpfs"; local.type = "bind"; local.bind.base = "ext4"; remote.type = "none"; swap.size = "8G"; swap.asPartition = true; };

    # Networking:
    networking.useDHCP = true;

    wip.base.enable = true;

    # Fix »raid0« module missing:
    imports = [ (lib.fun.makeNixpkgsModuleConfigOptional "tasks/swraid.nix" { }) ];
    disableModule."tasks/swraid.nix" = true;


}) ({ ## Other Temporary Test Stuff

    services.getty.autologinUser = "root";
    users.users.root.password = "root"; # Don't keep this for anything but local testing!

    boot.kernelParams = lib.mkForce [ "boot.shell_on_fail" ];

    #services.openssh.enable = true;
    wip.services.dropbear.enable = true; # (allows password login)
    #wip.services.dropbear.rootKeys = [ ''${lib.readFile "${dirname}/../utils/...pub"}'' ];

    boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
    documentation.nixos.enable = false;

    environment.systemPackages = [ pkgs.tmux pkgs.htop pkgs.libubootenv ];

    boot.kernelPackages = lib.mkIf (config.nixpkgs.crossSystem == null) (lib.mkForce pkgs.linuxPackages); # When not cross-compiling, building the i.MX Kernel on x64 (through qemu) takes quite a long time. The default (hydra built) aarch64 Kernel also works for the most part. (Might want to remove this later and then rebuild the proper kernel on the board.)

})  ]; }
