
# NixOS for i.MX (8)

As part of my master thesis I need to run experiments booting NixOS on an "IoT"-ish device that has a reasonably industry-standard boot architecture.
NXP kindly provided me with an i.MX 8M Plus EvaluationKit board, so here are Nix packages that build -- and a NixOS module that "installs" -- the boards firmware, bootloader, and kernel.


## Status

* All boot components (except the proprietary [`firmware-imx`](./overlays/firmware-imx.nix.md)) are built from sources, and they seem to be working fine.
* The board boots both with the mainline kernel and with NXP's fork. (At least) serial, USB and Ethernet work with either.
* Only NXP's kernel enables HDMI output (for TTYs), but GPU drivers are still missing (or not configured).
* Some things in the [`imx8-boot`](./modules/imx8-boot.nix.md) module, especially the script constructing `default-boot-image`, are somewhat specific to the `iMX8MP` and may very well require adjustments for other i.MX boards.


## Usage

This repository exports its NixOS module, host configurations, and its nixpkgs overlays, including their packages, as a Nix flake, and thus expects to be used by other Nix flakes.

When aiming to configure a NixOS host running on an i.MX, and starting from scratch, it may be a good starting point to copy the `flake.nix` and `host/imx8mp.nix.md`. Then rename and adjust the file in `hosts/`, and call `nix build` to see if things work. [`host/imx8mp.nix.md`](./host/imx8mp.nix.md) has basic instructions on how to create a boot medium from the configuration.


## License

All files in this repository ([`nixos-imx` / NixOS for i.MX](https://github.com/NiklasGollenstede/nixos-imx)) (except COPYING*) are authored by the authors of this repository, and are copyright 2022 Niklas Gollenstede.

"NixOS for i.MX" is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

"NixOS for i.MX" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with "NixOS for i.MX". If not, see <https://www.gnu.org/licenses/>.

This license applies to the files in this repository only. Any external packages are built built from sources that have their own licenses, which should be the ones indicated in the packages metadata.
