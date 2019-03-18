#!/bin/sh

SGFVER=23
SGFDIR=signify-$SGFVER
SGFSRC=v23.tar.gz

get_url https://github.com/aperezdc/signify/archive/v$SGFVER.tar.gz

tar xzf $SGFSRC

chmod 777 $SGFDIR -R

workrun make -C $SGFDIR \
	PREFIX=/usr \
	LTO=1 \
	MUSL=1 \
	BUNDLED_LIBBSD_VERIFY_GPG=0 \
	EXTRA_CFLAGS='-Os -s' \
	EXTRA_LDFLAGS='-static' \
	GIT_TAG=''

workrun make -C $SGFDIR \
	PREFIX=/usr \
	GIT_TAG='' install

add_file /bin/busybox
add_file /bin/signify
add_file /etc/version
add_file /etc/verify.pub

chmod u+s build/bin/busybox
