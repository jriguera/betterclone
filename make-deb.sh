#!/usr/bin/env bash
set -e
set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x

mkdir -p deb
rm -rf dev/*
dpkg-buildpackage -rfakeroot -us -uc -b
mv -f ../betterclone_* deb/

