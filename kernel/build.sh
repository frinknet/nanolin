#!/bin/sh

LNXVER=4.14.15
RTPVER=rt13

LNXDIR=linux-$LNXVER
RTPTCH=patch-$LNXVER-$RTPVER.patch

LNXFILE=$LNXDIR.tar.gz
RTPFILE=$RTPTCH.gz

# add the files
get_url https://www.kernel.org/pub/linux/kernel/v${LNXVER%%.*}.x/$LNXFILE
get_url https://www.kernel.org/pub/linux/kernel/projects/rt/${LNXVER%.*}/older/$RTPFILE

[ ! -e "$LNXDIR" ] && busybox tar xzf $LNXFILE
[ ! -e "$RTPTCH" ] && busybox zcat $RTPFILE > $RTPTCH

# make sure that .config.old exists so that we can compare
touch "$LNXDIR/.config.old"

# diff config before update with what we have since update may change it
CONFDIFF=$(busybox comm -3 "build/config" "$LNXDIR/.config.old")

# if no differences in config simply remove it
[ -z "$CONFDIFF" ] && rm build/config

# otherwise add patches to build
mv build/config $LNXDIR/.config
mv build/*.patch ./  2>/dev/null

# run all patches and check if the source was patched
patch_src $LNXDIR *.patch && SRCPATCH=1

# only reconfigure if there is a good reason because of patching or config changes
if [ -n "$CONFDIFF$SRCPATCH" ]; then
	[ -n "$SRCPATCH" ] && echo "Source was patched"
	[ -n "$CONFDIFF" ] && echo "Config file changed"

	echo "Updating config"
	yes "" | workrun make -C $LNXDIR config || return 1

	echo "Insuring fresh image is compiled"
	rm -f $LNXDIR/arch/x86/boot/bzImage
fi

# only build if we don't have a kernel file ready to go
if [ ! -e "$LNXDIR/arch/x86/boot/bzImage" ]; then
	info "Building Linux"

	yes "" | workrun make -C $LNXDIR || return 1
fi

# copy image to dropoff point
cp $LNXDIR/arch/x86/boot/bzImage image.gz
