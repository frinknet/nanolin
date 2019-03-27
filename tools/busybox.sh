#!/bin/sh

PACKAGE=busybox
VERSION=1.30.1
_DIR=$_PKG-$_VER
TARBALL=$_DIR.tar.bz2
DOWNLOAD=https://busybox.net/downloads/$_SRC
_GEN=$_DIR/$_PKG

package_download() {
	inc_url $_URL
}

package_unpack() {
	tar xjf $_SRC
}

package_config() {
	yes "" | workrun make -C $_DIR config
}

package_build() {
	make -C $_DIR \
		PREFIX=/usr \
		CC=musl-gcc
}

package_final() {
	make -C $_DIR \
		PREFIX=/usr \
		install

	add_file /bin/busybox

	chmod u+s build/bin/busybox

	add_license $_DIR
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
[ -n "$(ls $_PKG.*.patch)" ] && patch_src $_DIR $_PKG.*.patch && _PATCH=1

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
