/*

# NixOS on i.MX Example

Example (and test) host configuration for running NixOS on an i.MX 8M Plus evaluation board (via microSD).


## Installation

To prepare the microSD `/dev/sdX`, as `sudo` user with `nix` installed, run:
```bash
 nix run '.#imx8mp' -- sudo install-system /dev/sdX
```
Then put the card into the board, and use the switch to re-enable power.


## Implementation

```nix
#*/# end of MarkDown, beginning of NixOS config flake input:
dirname: inputs: specialArgs@{ config, pkgs, lib, name, ... }: let inherit (inputs.self) lib; in let
    hash = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);
in { imports = [ ({ ## Hardware

    wip.preface.hardware = "aarch64"; system.stateVersion = "22.05";

    # Booting:
    nxp.imx8-boot.enable = true; nxp.imx8-boot.soc = "iMX8MP";
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "firmware-imx" ];

    # Disk setup:
    wip.fs.disks.devices.primary.size = 31914983424; # If this mismatches, use whatever the installer says.
    wip.fs.temproot = { enable = true; temp.type = "tmpfs"; local.type = "bind"; local.bind.base = "f2fs"; remote.type = "none"; swap.size = "8G"; };

    # Networking:
    networking.useDHCP = true;

    wip.base.enable = true;

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

    boot.kernelPackages = lib.mkForce pkgs.linuxPackages; # building the i.MX kernel on x64 is quite time consuming and not always necessary, might want to remove this later and then rebuild the proper kernel on the board

})  ]; }
