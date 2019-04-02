#!/bin/sh

[ -n "$NLDBG" ] && echo "DEBUG: $0 $@"

# check that package file exists
PKGMKR="$0"
PKGDEF=${1##*/}
PKGRUN="$(echo $2 | tr '[:lower:]' '[:upper:]')"
PKGSTR="$(echo $2 | tr '[:upper:]' '[:lower:]')"
PKGDIR=${PKGDIR:-${1%%$PKGDEF}}
PKGDIR=${PKGDIR:-/var/packages}
PKGOUT="${PKGOUT:-/usr/local/repo}"
PKGSRC="${PKGSRC:-/src/}"
PKGDST="$PKGSRC/$PKGDEF"
PKGDOC="$PKGDIR/$PKGDEF"
PKGUSE="
    Usage:

	$NLCLI ${NLACT/./ } <package>
	$NLCLI ${NLACT/./ } <package> <action>

    Actions:

	prepare
	inspect
	release
	cleanup
	refresh

    Build Stages:

	sources
	patches
	builder
	install
	scripts
	removes
"

shift
shift

[ -z "$PKGDEF" ] && echo "$NLHDR
	Build a $NLSTR Package
$PKGUSE" && exit 1

# make sure the package recipe exists
[ ! -e "$PKGDOC" ] && echo "$NLHDR
	Invalid package name $PKGDEF

    Find a package:

	$NLCLI package list [searches]
" && exit 1

# pkgline helper function
pkgline() {
	grep "^$1" "$PKGDOC" | sed "s%^$1 %%"
}

# display info pretty
info() {
	echo -e "\e[1m$@\e[21m"
	sleep 1
}

# shell friendly answer to xargs -r
runeach() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:runeach() $@"

	while read -r x; do
		[ -z "$x" ] && continue
		$@ $x || exit 1
	done
}

# get file
getfile() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:getfile() $@"

	local GETURL="$1"
	local GETMD5="$2"
	local GETSRC="$PKGDST/${1##*/}"

	[ -e "$GETSRC" ] && info "File exists... $GETSRC" && return

	info "Retriving file... $GETSRC"

	# do everything inside $PKGDST
	(cd "$PKGDST";wget "$GETURL")

	# do integrity check
	[ -n "$GETMD5" ] && [ ! "$GETMD5" == "$(cd "$PKGDST";busybox md5sum "$GETSRC")" ] && echo "$NLHDR
	Download failed integrity check: $GETSRC

	$GETURL
	$GETMD5
	" && rm -rf "$GETSRC" && exit 1

	# extract if needed
	if ! case "$GETSRC" in
		*.tar.gz|*.tgz) busybox tar -C "$PKGDST" -xzf "$GETSRC";;
		*.tar.bz2) busybox tar -C "$PKGDST" -xjf "$GETSRC";;
		*.tar.xz) busybox tar -C "$PKGDST" -xJf "$GETSRC";;
		*.tar) busybox tar -C "$PKGDST" -xf "$GETSRC";;
		*.zip) busybox unzip -d "$PKGDST" "$GETSRC";;
		*.gz) (cd "$PKGDST";busybox gunzip "$GETSRC");;
		*.xz) (cd "$PKGDST";busybox xz -d  "$GETSRC");;
		*.bzip2) (cd "$PKGDST";busybox bzip2 -k -d "$GETSRC");;
	esac; then
		echo "$NLHDR
	Download failed to extract: $GETSRC
	"
		rm -rf "$GETSRC"
		exit 1
	fi
}

# put file
putfile() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:putfile() $@"

	local PUTSRC="$PKGDST/$1"

	[ -e "$PUTSRC" ] && info "File exists... $PUTSRC" && return

	info "Generating file... $PUTSRC"

	sed -rn ":a;N;\$!ba;s%.*\nPUTFILE $1((\n\t[^\n]*|\n\s*)*).*%\1%p" "$PKGDOC" | sed "s%^\t%%g" > "$PUTSRC" || exit 1
}

# patch a file
patched() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:patched() $@"

	local PATCHDIR="$1"
	local PATCHCNT="0"

	shift

	# loop through patches
	for x in $@; do
		# make sure the patch is not applied yet
		[ -e "${x%.patch}.applied" ] && continue
	
		# tell them that we are applying the patch
		info "Applying patch... $PKGDST/$x"
	
		# patch and put log in applied
		if ! (cd "$PKGDST/$PATCHDIR"; busybox patch -Np1 -i "$PKGSRC/$x") > ${x%.patch}.applied; then
			echo "$NLHDR
	Failed to apply patch to $PATCHDIR:

	patch -Np1 -i $x
	"
			exit 1
		fi

		# increment count
		$((++PATCHCNT))
	done

	# return success 
	[ "$PATCHCNT" -gt 0 ] && return 0 || return 1 
}

genscript() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:genscript() $@"

	local PKGRUN="$(echo $1 | tr '[:lower:]' '[:upper:]')"
	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	local PKGDST="$PKGDST/$NLCLI-$PKGSTR.sh"

	# run the newly created script
	info "Generating file... $PKGDST"

	# begin generation
	if ! (

	# add script header
	echo -e '#!/bin/sh'
	echo

	# add possible args
	echo "# $PKGSTR definition"
	echo -e "PKGHDR='AUTOMATIC PACKAGE $PKGRUN SCRIPT for $PKGDEF
Last updated: $(date)
Gnerated unsing $NLSTR v$NLVER

	$NLCLI ${NLACT/./ } $PKGDEF $PKGSTR
'"
	echo "PKGOPT='$(grep "^$PKGRUN" "$PKGDOC" | sed -r "s%^$PKGRUN ([^ ]*).*%\1%g")'"
	echo

	# add exports
	echo "# package variables available in script"
	sed -rn "s%^(BUILDER|INSTALL|REMOVES|PATCHES|SCRIPTS|GETFILE|PUTFILE|PATCHES) [^\n]*%%g;s%^([A-Z]*) ([^\n]*)%export \1='\2'%p" "$PKGDOC"  
	echo


	# switch to $PKGSRC to run but not for scripts
	if [ "$PKGRUN" == "SCRIPTS" ]; then
		echo "# switch to root for scripts"
		echo 'cd /'
		echo
	else
		echo "# switch to script root"
		echo 'cd "${0%/*}"'
		echo
	fi

	# find the build to run
	echo "# cases allowed in this $PKGSTR"
	echo '(case "$1" in'

	# add usage message
	echo -e "# show usage\n'')
	echo -e \"\$PKGHDR

    Script usage:

	${PKGDST##*/} <$PKGSTR>
	
    Available ${PKGSTR}s:
	\"

	echo \"\$PKGOPT\" | sed 's%^%\\t%g'
	echo
	;;"

	# add all builds in PKGDOC	
	sed -r "
		:a
		N
		\$!ba
		
		s%$%#!!!#%
		:b
		s%($PKGRUN [^\n]*(\n\t[^\n]*|\n[\t ]*)*)(.*#!!!#.*)%\3\n\1\t;;%
		tb
		
		s%\b$PKGRUN ([^\n]*)%# $PKGSTR for \1\n'\1')%g
		s%.*#!!!#\n*%%
	" "$PKGDOC"

	# add all target
	echo -e "# $PKGSTR for all\nall)
	echo \$PKGOPT | \
	while read -r x; do
		[ -z \"\$x\" ] && continue
		\"\$0\" \"\$x\"
	done
	;;
	
	"
	# add fuzzy matching for
	echo -e "# $PKGSTR for fuzzy matches\n*)
	echo \$PKGOPT | grep \"\$(printf '%q' \"\$1\")\" | \
	while read -r x; do
		[ -z \"\$x\" ] && continue
		\"\$0\" \"\$x\"
	done
	;;
	
	"

	# close out the switch case
	echo -e "esac) || echo \"\$PKGHDR

	Failed $PKGDEF $PKGSTR.\n\n\${0##*/} \$@\n\""

	# pipe everything we've just written to file
	) > "$PKGDST"; then
		echo "$NLHDR
	Failed to generate $PKGDST
	"
		exit 1
	fi

	chmod +x "$PKGDST"
}

overlay() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:overlay() $@"

	# set up variables 
	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	local PKGDEL="$PKGDST/$NLCLI-$USER-delete"
	local PKGWRK="$PKGDST/$NLCLI-$USER-$PKGSTR"
	local PKGMNT="$PKGDST/$NLCLI-$USER-overlay"
	local PKGBED="$(ls -d / "$PKGDST/$NLCLI-$USER-"* 2>/dev/null| grep -v "\($PKGSTR\|delete\|overlay\)$" | tr "\n" ":" | sed "s%:$%%")"

	shift

	[ -e "$PKGMNT" ] && echo "$NLHDR
	You are in the $PKGDEF $PKGSTR overlay in another terminal.
	" && exit 1

	# set up directories
	mkdir -p "$PKGDEL"
	mkdir -p "$PKGWRK"
	mkdir -p "$PKGMNT"

	info "Creating $PKGDEF $PKGSTR overlay... $PKGWRK"

	# do mount
	echo mount -t overlay overlay  -o "lowerdir=$PKGBED,workdir=$PKGDEL,upperdir=$PKGWRK" "$PKGMNT"
	if ! mount -t overlay overlay  -o "lowerdir=$PKGBED,workdir=$PKGDEL,upperdir=$PKGWRK" "$PKGMNT"; then
		echo "$NLHDR
	Failed to mount overlay: $PKGMNT
	"
		exit 1
	fi

	info "Overlay $PKGDEF $PKGSTR running... $@"

	# run chroot
	busybox chroot "$PKGMNT" $@

	# return can ony be processed after unmount
	PKGRTN=$?

	# simply unmount the work directory
	if ! umount "$PKGMNT"; then
		echo "$NLHDR
	Failed to unmount overlay: $PKGMNT
	"
		exit 1
	fi

	# remove mount dir
	rm -rf "$PKGMNT" "$PKGDEL"

	#check if we had errors
	[ "$PKGRTN" == "0" ] && return

	# surpress errors if inspecting
	[ "$@" == "$SHELL" ] && return
	
	# note if errors existed
	echo "$NLHDR
	Failed to execute in $PKGSTR overlay:

	$@
	" && exit 1
}

runscript() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:runscript() $@"

	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	local PKGGEN="$PKGDST/$NLCLI-$PKGSTR.sh"
	local PKGARG="$2"

	[ ! -e "$PKGGEN" ] && echo "$NLHDR
	Generator doesnt exist.

    Create a generator:

    	$NLCLI ${NLACT/./ } <package> <generator>

    Generators:

	builder
	install
	removes
	scripts
	" && exit 1

	if ! overlay "$PKGSTR" "$PKGGEN" "$PKGARG"; then
		echo "$PKGHDR
	Failed to execute generator: $PKGGEN
	"
		exit 1
	fi
}

pkgmake() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:pkgmake() $@"

	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"

	shift

	"$PKGMKR" "$PKGDEF" $PKGSTR $@
}

pkgimage() {
	info "Creating package $PKGDEF.img..."

	local PKGREL="$(date R+%y.%m-G%d%H%M%S)"
	local PKGWRK="$PKGDST/$NLCLI-$USER-install"
	local PKGIMG="$PKGOUT/$PKGDEF-$VERSION-$PKGREL.img"

	(cd "$PKGWRK"; find . | busybox cpio -o -H newc) | busybox gzip -9 > "$PKGIMG"
}

# description
export PACKAGE=$(pkgline PACKAGE)
export VERSION=$(pkgline VERSION)
export COMMENT=$(pkgline COMMENT)

# dependencies
export PROVIDE=$(pkgline PROVIDE)
export REQUIRE=$(pkgline REQUIRE)
export HELPFUL=$(pkgline HELPFUL)
export DEPENDS=$(pkgline DEPENDS)
export CLASHES=$(pkgline CLASHES)

# support
export CONTACT=$(pkgline CONTACT)
export WEBSITE=$(pkgline WEBSITE)
export BUGTALK=$(pkgline BUGTALK)
export LICENSE=$(pkgline LICENSE)

# remote 
export PKGREPO=$(pkgline PKGREPO)
export PKGDATE=$(pkgline PKGDATE)
export PKGSIGN=$(pkgline PKGSIGN)
export PKGDIST=$(pkgline PKGDIST)

# make sure we have the destination directory
[ ! -e "$PKGDST" ] && info "Creating source directory... $PKGDST" && mkdir -p "$PKGDST"

case "$PKGRUN" in
SOURCES)
	grep "^GETFILE" "$PKGDOC" | sed "s%^GETFILE%%g" | runeach getfile || exit 1
	grep "^PUTFILE" "$PKGDOC" | sed "s%^PUTFILE%%g" | runeach putfile || exit 1
	;;
PATCHES)
	grep "^PATCHES" "$PKGDOC" | sed "s%^PATCHED%%g" | runeach patched || exit 1
	;;
BUILDER|INSTALL|REMOVES|SCRIPTS)
	genscript "$PKGRUN"

	[ -n "$1" ] && runscript "$PKGRUN" "$1"
	;;
PREPARE)
	pkgmake sources 
	pkgmake patches
	pkgmake builder all
	pkgmake install all
	;;
RELEASE)
	pkgmake prepare
	pkgimage

	echo "$NLHDR
	RELEASE TODO;

	# sign the local repo image
	# add to local repo packages.tgz
	# add to local repo manifest.tgz
	"
	;;
INSPECT)
	PKGRUN="$(echo $1 | tr '[:lower:]' '[:upper:]')"

	case "$PKGRUN" in
	BUILDER|INSTALL|REMOVES|SCRIPTS)
		shift

		overlay $PKGRUN ${@:-$SHELL}
		;;
	'')
		pkgmake prepare
		pkgmake inspect install
	esac
	;;
CLEANUP)
	# allow cleanup of only part
	[ -e "$1" ] && PKGDST="$PKGDST/$1"

	# remove all files
	[ ! -d "$PKGDST" ] && echo "$NLHDR
		Package ${1:-build} directory does not exists for $PKGDEF!
	" && exit 1
	
	# make sure before deleting
	read -n1 -p "Are you sure you want to clean up $PKGDEF ${1:-build} directory? [y/N] " PKGREM < /dev/tty
	
	# check that we did want to delete the dir
	if echo "$PKGREM" | grep -qi Y; then
		umount "$PKGDST/$NLCLI-"*"-overlay" &>/dev/null
		rm -rf "$PKGDST"
		echo -e "\n\n\tRemoved: $PKGDST\n"
	else
		echo -e "\n\n\tKeeping: $PKGDST\n"
	fi
	;;
REFRESH)
	yes | pkgmake cleanup
	pkgmake release
	;;
'')
	pkgmake release
	;;
*)
	echo "$NLHDR
	Build a $NLSTR Package
	$PKGUSE" && exit 1
	;;
esac 
