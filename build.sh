#!/bin/sh

# basic config
SRC="$(readlink -f "$1")"
IMG="$(basename "$1")"
DIR="$(readlink -f "$(dirname "$PWD/$1")")"
WRK="$DIR/work/$IMG"
GEN="$DIR/work/out"
TAR="$DIR/work/$IMG-release.tgz"
OUT="$DIR/$IMG-release.tgz"
REL="Nanolin.$IMG"

[ -z "$KNL" ] && export KNL="$IMG"

shift

[ -z "$DSK" ] && export DSK="$@"

#load config file if it exists
[ -e "$DIR/config" ] && source "$DIR/config"

#alias chroot for easy work
alias busybox="$WRK/usr/bin/busybox"
alias workroot="busybox chroot '$WRK'"
alias workbox="workroot /usr/bin/busybox"

info() {
	echo -e "\e[1m$@\e[21m"
}

clean_file() {
	for x in $@; do
		[ -e "$x" ] && echo "Removing $x"
		rm -fr "$x"
	done
}

clean_dir() {
	for x in $@; do
		echo "Creating $x"
		rm -fr "$x"
		mkdir -p "$x"
	done
}

add_file() {
	for x in $@; do
		echo "Adding $x"
		workbox cp "$x" "/build$x"
	done
}

add_dir() {
	for x in $@; do
		echo "Adding $x"
		workbox cp -fr "$x/*" "/build/$x/"
	done
}

get_url() {
	for x in $@; do
		[ -e "${x##*/}" ] && continue

		echo "Retrieving $x"
		busybox wget "$x"
	done
}

setup_dir() {
	rm -rf $1
	mkdir -p $1
	cd $1

	mkdir -p boot
	mkdir -p dev
	mkdir -p etc/nanolin.d
	mkdir -p home
	mkdir -p mnt/user
	mkdir -p mnt/uuid
	mkdir -p mnt/label
	mkdir -p mnt/dev
	mkdir -p mnt/nobs
	mkdir -p proc
	mkdir -p root
	mkdir -p run/lock
	mkdir -p run/distro
	mkdir -p sys
	mkdir -p tmp/var
	mkdir -p usr/bin
	mkdir -p usr/lib
	mkdir -p usr/local
	mkdir -p usr/include
	mkdir -p usr/share
	mkdir -p usr/src
	mkdir -p var/log
	mkdir -p var/cache
	mkdir -p var/spool/cron
	mkdir -p var/spool/cron/crontabs
	mkdir -p var/spool/mail
	ln -s usr/bin bin
	ln -s usr/bin sbin
	ln -s usr/lib lib
	ln -s usr/lib lib64
	ln -s ../bin usr/sbin
	ln -s ../lib usr/lib64
	ln -s ../proc/mounts etc/mtab
	ln -s ../../etc/hostname run/distro/hostname
	ln -s ../../etc/username run/distro/username
	ln -s ../../etc/version run/distro/version
	ln -s ../../etc/remote run/distro/remote
	ln -s ../run var/run
	ln -s ../run/lock var/lock
	ln -s ../distro run/lock/distro
	ln -s ../tmp/var var/tmp
	ln -s spool/mail var/mail
	chmod -R 777 tmp
	chmod -R 722 run/distro
	chmod -R 777 run/lock
	cd -
}

patch_src() {
	local _SRC="$1"
	local _CNT="0"

	shift

	for x in $@; do
		[ -e "${x%.patch}.applied" ] && continue
	
		echo "Applying $x"
	
		(cd $_SRC; busybox patch -Np1 -i ../$x) > ${x%.patch}.applied
		$((++CNT))
	done

	[ "$_CNT" -gt 0 ] && return 0 || return 1 
}

img_dir() {
	echo "Creating image $2 from $1"

	(cd "$1"; find . | busybox cpio -o -H newc) | busybox gzip -9 > "$2"
}

run_in_dir() {
	local _SRC=$1
	local _DIR=$2

	

	info "Running $_SRC"

	if ! (cd "$_DIR"; source "$_SRC"); then
		echo "Error in $_SRC"
		echo "Running in $_DIR"

		return 1
	fi
}

# make sure we have a base director
[ ! -d "$SRC" ] && echo "
Missing directories to build.
" && exit

# make sure we have signify installed
if [ ! -e "/usr/bin/signify" ]; then
	info "Signify needs to be installed to sign packages."

	yes | sudo pacman -Sy signify

	echo "Run again to continue."
	exit
fi

# generate verify keys if needed
if [ ! -e "$DIR/verify.pub" ] || [ ! -e "$DIR/verify.sec" ]; then
	info "Generating verify key for release"

	signify -Gn -p "$DIR/verify.pub" -s "$DIR/verify.sec"
fi

info "Preparing to build from $SRC" 

# recreate build directory fresh 
mkdir -p "$GEN"
echo "setup $WRK/build"
setup_dir "$WRK/build" 
clean_file "$WRK/image.gz" "$TAR"

# make sure we have a version but only record once
if [ ! -e "$GEN/.version" ]; then
	date +%y.%m-G%d%H%M%S > "$GEN/.version"
fi

# create release
echo "Storing version and verify.pub key"
REL="$REL-$(cat "$GEN/.version")"
OUT="$REL.tgz"
mkdir -p "$WRK/etc"
echo "$REL" > "$WRK/etc/version"
cp "$DIR/verify.pub" "$WRK/etc/verify.pub"

#packstrap busybox + packages
info "Pacstrap $SRC/packages"
pacstrap -d "$WRK" busybox $(grep -v '#' "$SRC/packages" 2>/dev/null) || (echo "
Error in pacsrap call. Aborting build for $IMG.
" && exit)

info "Preparing build environment"
# install busybox in overlay build directory
echo "Setting up busybox commands in chroot"
workbox --install -s /bin

# tar copy everything except build.sh and pakages from $SRC
echo "Copying files to $WRK/build"
tar -C "$SRC" --exclude=build.sh --exclude=packages -cf - . | tar -C "$WRK/build" -xf -

# if we have a build.sh file copy it to $WRK
[ -e "$SRC/build.sh" ] && run_in_dir "$SRC/build.sh" "$WRK" || exit

info "Adding image to release"

# if there is not a build image file genrate ona if there is a build directory
[ ! -e "$WRK/image.gz" ] && [ -e "$WRK/build" ] && img_dir "$WRK/build" "$WRK/image.gz"

# copy image
[ ! -e "$WRK/image.gz" ] && echo "No image found at $WRK/image.gz" && exit

# add the image to the generation folder
echo "Copying image to $GEN/$IMG"
mv "$WRK/image.gz" "$GEN/$IMG"

# generate manifest
echo "Updating manifest $GEN/.manifest"
(cd "$GEN"; "$WRK/bin/busybox" sha1sum *) > "$GEN/.manifest"

# generate signature
echo "Signing manifest $GEN/.signature"
signify -S -s "$DIR/verify.sec" -m "$GEN/.manifest" -x "$GEN/.signature"

# continue building next target
[ -z "$@" ] || exec $0 $@

# finalize target
info "Finalizing $REL release tarball"

# generate boot file
echo "PATH /$REL/
DEFAULT boot
LABEL boot
KERNEL $KNL
INCLUDE /.bootflags" > "$GEN/boot"

[ -n "$DSK" ] && echo "INITRD ${DSK/ /,}" >> "$GEN/boot"

# create release
tar -C "$GEN" -czf "$TAR" .

# sign the release
echo "Signing release $OUT"
signify -Sz -s "$DIR/verify.sec" -m "$TAR" -x "$OUT"

# clean generation output file
#rm -rf "$GEN"
