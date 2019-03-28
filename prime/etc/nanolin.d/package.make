#!/bin/sh

[ -n "$NLDBG" ] && echo "DEBUG: $0 $@"

# check that package file exists
PKGDEF=${1##*/}
PKGDIR=${PKGDIR:-${1%%$PKGDEF}}
PKGDIR=${PKGDIR:-/var/packages}
PKGSRC="${PKGSRC:-/src/$PKGDEF}"
PKGDOC="$PKGDIR/$PKGDEF"

# show usage if needed
[ -z "$PKHDEF" ] && echo "$NLHDR
	Build a $NLSTR Package

    Usage:

	$NLCLI ${NLACT/./ } <package>
" && exit 1

# make sure package exists
[ ! -e "$PKHDOC" ] && echo "$NLHDR
	Invalid package name $PKGDEF

    Usage:

	$NLCLI ${NLACT/./ } <package>
" && exit 1

mkdir -p "$PKGSRC"

# pkgline helper function
pkgline() { grep "^$1" "$PKGDOC" | sed "s%^$1 %%" }

# description
export PACKAGE=$(pkgline PACKAGE)
export VERSION=$(pkgline VERSION)
export COMMENT=$(pkgline COMMENT)

# dependencies
export DEPENDS=$(pkgline DEPENDS)
export CLASHES=$(pkgline CLASHES)
export ALIASES=$(pkgline ALIASES)

# support
export CONTACT=$(pkgline CONTACT)
export WEBSITE=$(pkgline WEBSITE)
export LICENSE=$(pkgline LICENSE)

# remote 
export PKGREPO=$(pkgline PKGREPO)
export PKGDATE=$(pkgline PKGDATE)
export PKGSIGN=$(pkgline PKGSIGN)
export PKGDIST=$(pkgline PKGDIST)

# shell friendly answer to xargs -r
runeach() {
	while read -r x; do
		[ -z "$x" ] && continue
		$@ $x
	done
}

# get file
getfile() {
	local _URL="$1"
	local _MD5="$2"
	local _SRC="${1##*/}"

	# do everything inside $PKGSRC

	# download the file
	(cd "$PKGSRC";wget "$_URL")

	# do integrity check
	[ ! "$_MD5" == "$(cd "$PKGSRC";busybox md5sum "$_SRC")" ] && echo "$NLHDR
	Download failed integrity check.
	$_URL
	$_MD5
	" rm -rf "$_SRC" && exit 1

	# extract if needed
	case "$_SRC"
	*.tar.gz|*.tgz) (cd "$PKGSRC";tar xzf "$_SRC");;
	*.tar.bz2) (cd "$PKGSRC";tar xjf "$_SRC");;
	*.tar) (cd "$PKGSRC";tar xf "$_SRC");;
	*.gz) (cd "$PKGSRC";gunzip "$_SRC");;
	esac
}

# put file
putfile() {
	sed "s%PUTFILE $1((\n\t[^\n]*|\n(\t\| )+)+)%\1)\2\n\t;;%p" "$PKGDEF" | sed "s%^\n\t%%g" > "$PKGSRC/$1"

}

# patch a file
patchset() {
	local _DIR
	local _CNT="0"

	# populate from last
	for _DIR in $@; do :; done

	# pop last argument
	set -- ${@%%$_DIR}

	# loop through patches
	for x in $@; do
		# make sure the patch is not applied yet
		[ -e "${x%.patch}.applied" ] && continue
	
		# tell them that we are applying the patch
		echo "Applying patch $x"
	
		# patch and put log in applied
		(cd "$PKGSRC/$_DIR"; busybox patch -Np1 -i "$PKGSRC/$x") > ${x%.patch}.applied || echo "$NLHDR
	Failed to apply patch to $_DIR:

	patch -Np1 -i $x
	"

		# increment count
		$((++_CNT))
	done

	# return success 
	[ "$_CNT" -gt 0 ] && return 0 || return 1 
}

# downloads
grep "^GETFILE" "$PKGDOC" | sed "s%^GETFILE%%g" | runeach getfile 

# inline files
grep "^PUTFILE" "$PKGDOC" | sed "s%^PUTFILE%%g" | runeach putfile

# patch sources
grep "^PATCHES" "$PKGDOC" | sed "s%^PATCHES%%g" | runeach patchset

# build source
"$NLBIN" package script BUILDER "$PKGDOC"

# install
# license
#
