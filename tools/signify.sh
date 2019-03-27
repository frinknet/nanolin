#!/bin/sh

_VER=24
_SRC=v$_VER.tar.gz
_DIR=signify-$_VER

# download signify source
inc_url https://github.com/aperezdc/signify/archive/$_SRC

rm -rf $_DIR

tar xzf $_SRC

chmod 777 $_DIR -R

make -C $_DIR \
	PREFIX=/usr \
	MUSL=1 \
	BUNDLED-LIBBSD=1 \
	BUNDLED_LIBBSD_VERIFY_GPG=0 \
	BZERO='bundled' \
	EXTRA_CFLAGS='-Os -s -static' \
	EXTRA_LDFLAGS='-static -nostdlib'

make -C $_DIR \
	PREFIX=/usr \
	install

add_file /bin/signify

add_license $_DIR
