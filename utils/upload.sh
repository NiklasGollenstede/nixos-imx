#!/usr/bin/env bash
set -eu

## Uses »rsync« to copy this nixos config to the host (or root FS mounted at) »$1«.
#  The target is expected to have »/etc/nixos/configuration.nix« link to »./hosts/XXX.nix«.

: ${config:="$(dirname -- "$(cd "$(dirname -- "$0")" ; pwd)")"}

target=${1:?"Required: Target host name or mount point."} ; shift

if [[ "$target" != *:* ]] ; then target="$target": ; fi
set -x
rsync \
--progress --checksum --inplace --no-whole-file \
--archive --update --delete --times --chown='0:1' --chmod=g-w \
--exclude-from="$config"/'.gitignore' \
"$@" \
"$config"/ "$target"/etc/nixos/

#--exclude='/.git' \
