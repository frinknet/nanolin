#!/bin/sh

_PKG=linux
_VER="4.14.15"
_DIR=linux-$_VER
_SRC=$_DIR.tar.gz
_URL=https://www.kernel.org/pub/linux/kernel/v${_VER%%.*}.x/$_SRC
_GEN=$_DIR/arch/x86/boot/bzImage

_RTV=rt13
_RTP=patch-$_VER-$_RTV.patch
_RTS=$_RTP.gz
_RTU=https://www.kernel.org/pub/linux/kernel/projects/rt/${_VER%.*}/older/$_RTS

package_download() {
	inc_url $_URL
	inc_url $_RTU 
}

package_unpack() {
	busybox tar xzf $_SRC
	busybox zcat $_RTS > $_RTS
}

package_config() {
	yes "" | workrun make -C $_DIR config
}

package_build() {
	yes "" | workrun make -C $_DIR
}

package_final() {
	cp $_GEN image.gz
}

# download signify source if needed
[ ! -e "$_SRC" ] && package_download

# extract tar if needed
[ ! -d "$_DIR" ] && package_unpack

# make sure that .config.old exists so that we can compare
touch "$_DIR/.config.old"

# diff config before update with what we have since update may change it
[ -e "$SRC/$_PKG.conf" ] &&_DIFF=$(busybox comm -3 "$SRC/$_PKG.conf" "$_DIR/.config.old")

# install config if it's different
[ ! -n "$_DIFF" ] && inc_config $_PKG $_DIR

# also add  other patches to build
mv build/$_PKG.*.patch ./  2>/dev/null

# run all patches and check if the source was patched
patch_src $_DIR $_PKG.*.patch && _PATCH=1

# only reconfigure if there is a good reason because of patching or config changes
if [ -n "$_DIFF$_PATCH" ]; then
	[ -n "$_PATCH" ] && echo "Source was patched"
	[ -n "$_DIFF" ] && echo "Config file changed"

	echo "Updating config"
	package_config

	echo "Insuring fresh image is compiled"
	rm -f $_GEN
fi

# only build if we don't have a kernel file ready to go
if [ ! -e "$_iGEN" ]; then
	info "Building $_PKG"
	package_build
fi

package_final
