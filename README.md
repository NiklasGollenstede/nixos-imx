
# NixOS for i.MX (8)

As part of my master thesis I need to run experiments booting NixOS on an "IoT"-ish device that has a reasonably industry-standard boot architecture.
NXP kindly provided me with an i.MX 8M Plus EvaluationKit board, so here are Nix packages that build -- and a NixOS module that "installs" -- the boards firmware, bootloader, and kernel.


## Status

* All boot components (except the proprietary [`firmware-imx`](./overlays/firmware-imx.nix.md)) are built from sources, and they seem to be working fine.
* The board boots both with the mainline kernel and with NXP's fork. (At least) serial, USB and Ethernet work with either.
* Only NXP's kernel enables HDMI output (for TTYs), but GPU drivers are still missing (or not configured).
* Some things in the [`imx8-boot`](./modules/imx8-boot.nix.md) module, especially the script constructing `default-boot-image`, are somewhat specific to the `iMX8MP` and may very well require adjustments for other i.MX boards.
* Cross-compiling (from `x64`) works and the resulting system boots.


## Usage

This repository exports its [NixOS module](./modules/), example [host configuration](./hosts/), and its [nixpkgs overlays](./overlays/), including their packages, as a [Nix flake](./flake.nix), and thus expects to be used by other Nix flakes.

When aiming to configure a NixOS host running on an i.MX, and starting from scratch, it may be a good starting point to copy the [`flake.nix`](./flake.nix) and [`host/imx8mp.nix.md`](./hosts/imx8mp.nix.md) to a new repo.
Then uncomment the `nixos-imx` input and remove the `overlays` variable in `flake.nix`, rename and adjust the file in `hosts/`, and call `nix build` to see if things work.
[`host/imx8mp.nix.md > Installation`](./hosts/imx8mp.nix.md#installation) has basic instructions on how to create a boot medium from the configuration.


### Building

Chances are that while the i.MX is `aarch64`, one wants to build its system installation (/OS image) on a `x64` host.

With Nix/NixOS, (generally) either all or none of a host's configuration has to be cross-compiled.
Anything else would be a huge mess to configure, and any dependencies that natively and cross-compiled packages have in common would (by default) not bw shared.

When building on a `x64` host, native `aarch64` builds can be executed via a qemu "user" binfmt registration.
This incurs a slowdown of about 10x on anything that needs to be built (like the i.MX Kernel), but the official NixOS binary caches provide prebuilds for any packages that are defined in `nixpkgs` and used without modifications.

Creating a binfmt registration should be quite easy on most Linux distributions. With that, only an `extra-platforms` entry in the Nix config should be required to run `aarch64` builds through emulation.
On NixOS, this is entirely handled by setting `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` in the building hosts configuration.

Nix itself supports cross-compiling quite well, but few people seem to be using it with NixOS.
Cross-compiling avoids the emulation slowdown, but the (official) binary cache can't be used, and (unless one sets up their own build cache) everything will have to be built locally from source, which overall may or may not be faster.
Most of the packages for the i.MX cross-compile, but one (`mkimage_imx8`) still requires qemu.
The [flake.nix](./flake.nix) defines additional hosts prefixed with `x64:`, which are cross-built from `x64` but should otherwise behave the same as their "normal" counterparts.


## License

All files in this repository ([`nixos-imx` / NixOS for i.MX](https://github.com/NiklasGollenstede/nixos-imx)) (except COPYING*) are authored by the authors of this repository, and are copyright 2022 Niklas Gollenstede.

"NixOS for i.MX" is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

"NixOS for i.MX" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU [Lesser](./COPYING.LESSER) [General Public License](./COPYING) along with "NixOS for i.MX". If not, see <https://www.gnu.org/licenses/>.

This license applies to the files in this repository only. Any external packages are built from sources that have their own licenses, which should be the ones indicated in the package's metadata.
