#!/bin/sh

TAR="$PWD/$1"
DIR=$(basename "$TAR" .tgz)

cd /boot/
rm -rf "$DIR"
mkdir -p "$DIR"
tar xzf "$TAR" -C "$DIR" && ln -sfn "$DIR" current 

BLKDEV=$(grep /boot /etc/mtab | cut -d' ' -f1)
eval $(blkid $BLKDEV | cut -d: -f2)

echo "boot=$UUID" > /boot/.bootflags
