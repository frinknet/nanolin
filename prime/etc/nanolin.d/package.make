#!/bin/sh

[ -n "$NLDBG" ] && echo "DEBUG: $0 $@"

# setup all of the special variables used in building
PKGMKR="$0"
PKGDEF=${1##*/}
PKGRUN="$(echo $2 | tr '[:lower:]' '[:upper:]')"
PKGSTR="$(echo $2 | tr '[:upper:]' '[:lower:]')"
PKGDIR=${PKGDIR:-${1%%$PKGDEF}}
PKGDIR=${PKGDIR:-/var/packages}
PKGOUT="${PKGOUT:-/usr/local/repo}"
PKGURL="${PKGURL:-file://$PKGOUT}"
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

# show usage if package file does not exists
[ -z "$PKGDEF" ] && echo "$NLHDR
	Build a $NLSTR Package
$PKGUSE" && exit 1

# show error if package recipe does not exists
[ ! -e "$PKGDOC" ] && echo "$NLHDR
	Invalid package name $PKGDEF

    Find a package:

	$NLCLI package list [searches]
" && exit 1

# helper function to get one package line
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

# import a file from a remote source
getfile() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:getfile() $@"

	# setup local vairables
	local GETURL="$1"
	local GETMD5="$2"
	local GETSRC="$PKGDST/${1##*/}"

	# make sure we need to get the file before we atempt to retrieve it
	[ -e "$GETSRC" ] && info "File exists... $GETSRC" && return

	info "Retriving file... $GETSRC"

	# get the file and put it in the right place
	(cd "$PKGDST";wget "$GETURL")

	# check the remote file integrity against supplied MD5 if it exists
	[ -n "$GETMD5" ] && [ ! "$GETMD5" == "$(cd "$PKGDST";busybox md5sum "$GETSRC")" ] && echo "$NLHDR
	Download failed integrity check: $GETSRC

	$GETURL
	$GETMD5
	" && rm -rf "$GETSRC" && exit 1

	# extract the file if it is a known file extension
	if ! case "$GETSRC" in
		*.tar.gz|*.tgz) busybox tar -C "$PKGDST" -xzf "$GETSRC";;
		*.tar.bz2|*.tbz) busybox tar -C "$PKGDST" -xjf "$GETSRC";;
		*.tar.xz|*.txz) busybox tar -C "$PKGDST" -xJf "$GETSRC";;
		*.tar) busybox tar -C "$PKGDST" -xf "$GETSRC";;
		*.zip) busybox unzip -d "$PKGDST" "$GETSRC";;
		*.gz) (cd "$PKGDST";busybox gunzip "$GETSRC");;
		*.xz) (cd "$PKGDST";busybox xz -d  "$GETSRC");;
		*.bz|*.bz2|*.bzip2) (cd "$PKGDST";busybox bzip2 -k -d "$GETSRC");;
	# if the extraction fails show a failure message and exit
	esac; then
		echo "$NLHDR
	Download failed to extract: $GETSRC
	"
		rm -rf "$GETSRC"
		exit 1
	fi
}

# import file from package recipe file
putfile() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:putfile() $@"

	# setup local variable
	local PUTSRC="$PKGDST/$1"

	# make sure we need to generate the file before doing anything
	[ -e "$PUTSRC" ] && info "File exists... $PUTSRC" && return

	info "Generating file... $PUTSRC"

	# extract the source from 
	sed -rn "
		# read the whole file
		:a
		N
		\$!ba

		# get the text of the file
		s%.*\nPUTFILE $1((\n\t[^\n]*|\n\s*)*).*%\1%p

	# remove leading tab in eacl line
	" "$PKGDOC" | sed "s%^\t%%g" > "$PUTSRC" || exit 1
}

# patch a dir
patches() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:patched() $@"

	# setup local variables
	local PCHDIR="$PKGDST/$1"
	local PCHNUM="0"

	shift

	# loop through patches
	for x in $@; do
		# make sure the patch is not applied yet
		[ -e "${x%.patch}.applied" ] && info "Patch applied... $PKGDST/$x" && $((++PCHNUM)) && continue

		# tell them that we are applying the patch
		info "Applying patch... $PKGDST/$x"

		# patch the source directory and put output log in .applied file
		if ! (cd "$PCHDIR"; busybox patch -Np1 -i "$PKGSRC/$x") > ${x%.patch}.applied; then
			echo "$NLHDR
	Failed to apply patch to $PCHDIR:

	patch -Np1 -i $x
	" &&
	       	exit 1
		fi

		# increment count
		$((++PCHNUM))
	done

	# return success if we have done what we need to 
	[ "$PCHNUM" -gt 0 ] && return 0 || return 1 
}

genscript() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:genscript() $@"

	# setup local variables
	local PKGRUN="$(echo $1 | tr '[:lower:]' '[:upper:]')"
	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	local PKGDST="$PKGDST/$NLCLI-$PKGSTR.sh"

	# notify that we are generating the script script
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
	sed -rn "s%^(BUILDER|TESTING|INSTALL|REMOVES|PATCHES|SCRIPTS|GETFILE|PUTFILE|PATCHES) [^\n]*%%g;s%^([A-Z]*) ([^\n]*)%export \1='\2'%p" "$PKGDOC"  
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
		# read whole file
		:a
		N
		\$!ba
		
		# find the $PKGRUN sections
		s%$%#!!!#%
		:b
		s%(\n$PKGRUN [^\n]*(\n\t[^\n]*|\n[\t ]*)*)(.*#!!!#.*)%\3\n\1\t;;%
		tb
		
		# replace section header with sh case str
		s%\n$PKGRUN ([^\n]*)%# $PKGSTR for \1\n'\1')%g

		# remove the other lines
		s%.*#!!!#\n*%%
	" "$PKGDOC"

	# add the all target case that will run other cases
	echo -e "# $PKGSTR for all\nall)
	echo \$PKGOPT | \
	while read -r x; do
		[ -z \"\$x\" ] && continue
		\"\$0\" \"\$x\"
	done
	;;
	
	"
	# add fuzzy matching case to allow partial builds
	echo -e "# $PKGSTR for fuzzy matches\n*)
	echo \$PKGOPT | grep \"\$(printf '%q' \"\$1\")\" | \
	while read -r x; do
		[ -z \"\$x\" ] && continue
		\"\$0\" \"\$x\"
	done
	;;
	
	"

	# close out the switch case a test for failure
	echo -e "esac) || echo \"\$PKGHDR

	Failed $PKGDEF $PKGSTR.\n\n\${0##*/} \$@\n\""

	# pipe everything we've just written to file or show an error if failed
	) > "$PKGDST"; then
		echo "$NLHDR
	Failed to generate $PKGDST
	"
		exit 1
	fi

	# make the new script executable
	chmod +x "$PKGDST"
}

overlay() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:overlay() $@"

	# setup local variables 
	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	local PKGDEL="$PKGDST/$NLCLI-$USER-delete"
	local PKGWRK="$PKGDST/$NLCLI-$USER-$PKGSTR"
	local PKGMNT="$PKGDST/$NLCLI-$USER-overlay"
	local PKGBED="$(ls -d / "$PKGDST/$NLCLI-$USER-"* 2>/dev/null| grep -v "\($PKGSTR\|delete\|overlay\)$" | tr "\n" ":" | sed "s%:$%%")"

	shift

	# make sure that only one overlay is running
	[ -e "$PKGMNT" ] && echo "$NLHDR
	You are in the $PKGDEF $PKGSTR overlay in another terminal.
	" && exit 1

	# setup delete, work and mount directories
	mkdir -p "$PKGDEL"
	mkdir -p "$PKGWRK"
	mkdir -p "$PKGMNT"

	info "Creating $PKGDEF $PKGSTR overlay... $PKGWRK"

	# mount the overlayfs
	echo mount -t overlay overlay  -o "lowerdir=$PKGBED,workdir=$PKGDEL,upperdir=$PKGWRK" "$PKGMNT"
	if ! mount -t overlay overlay  -o "lowerdir=$PKGBED,workdir=$PKGDEL,upperdir=$PKGWRK" "$PKGMNT"; then
		echo "$NLHDR
	Failed to mount overlay: $PKGMNT
	"
		exit 1
	fi

	# notify that we have an overlay ready
	info "Overlay $PKGDEF $PKGSTR running... $@"

	# run nanolin chroot for full transparency
	"$NLBIN" chroot "$PKGMNT" $@

	# return can ony be processed after unmount
	PKGRTN=$?

	# make sure that we unmount everything
	# TODO; make a trap for this
	if ! umount "$PKGMNT"; then
		echo "$NLHDR
	Failed to unmount overlay: $PKGMNT
	"
		exit 1
	fi

	# notify that we are finished with overlay
	info "Overlay $PKGDEF $PKGSTR finished... $@"

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

	# setup local variables
	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	local PKGGEN="$PKGDST/$NLCLI-$PKGSTR.sh"
	local PKGARG="$2"

	# make sure the generator exists
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

	# make sure the overlay run as expected
	if ! overlay "$PKGSTR" "$PKGGEN" "$PKGARG"; then
		echo "$PKGHDR
	Failed to execute generator: $PKGGEN
	"
		exit 1
	fi
}

pkgmake() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:pkgmake() $@"

	# setup local variable
	local PKGSTR="$(echo $1 | tr '[:upper:]' '[:lower:]')"

	shift

	# run a loopback call to self with new arguments
	"$PKGMKR" "$PKGDEF" $PKGSTR $@
}

getlicense() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:getlicense() $@"

	# setup local variable
	local PKGWRK="$PKGDST/$NLCLI-$USER-install/var/licenses"
	local PKGLIC="$PKGWRK/$PACKAGE-$VERSION"

	# run the license extractor on $PKGDST
	"$NLCLI" package.license "$PKGDST"

	# make licenses directory
	mkdir -p "$PKGWRK"

	# move license file to proper resting place
	mv "$PKGDST/.licenses" "$PKGLIC"
}

pkgbundle() {
	[ -n "$NLDBG" ] && echo "DEBUG: $0:pkgblog() $@"

	# setup local variables
	local PKGREL="$(date +R%y.%m)"
	local PKGGEN="$(date +G%d%H%M%S)"
	local PKGWRK="$PKGDST/$NLCLI-$USER-install"
	local PKGIMG="$PACKAGE-$VERSION$REVISED-$PKGREL"

	info "Creating $NLSTR Bundle $PKGIMG.nbz..."

	# remove all bz2 file so we can star fresh
	rm -rf package.tgz *.bz > /dev/null
	
	# finalize recipe for inclusion
	(
		# remove references to the dist
		grep -v "^DIST" "$PKGDOC" 
		echo

		# add dist stuff
		echo DISTURL $PKGURL
		echo DISTREL $PKGREL
		echo DISTGEN $PKGGEN
	# create recipe.bz
	) | busybox bzip2 -c > "$PKGDST/recipe.bz"

	# create overlay.bz
	busybox tar -C "$PKGWRK" --exclude=root -cjf "$PKGDST/overlay.bz"

	# prepare manifest for inclusion
	(
		cd "$PKGWRK"
		busybox md5sum $(tar -tjf "$PKGDST/overlay.bz")
	# create manifest.bz
	) | busybox bzip2 -c > "$PKGDST/manifest.bz"

	# build the tgz file to get ready for signing
	tar -czf package.tgz recipe.bz manifest.bz overlay.bz

	# sign the package
	signify -Sz -s "$PKGOUT/.sign-secret" -m "$PKGDST/package.tgz" -x - | \
	sed -r "s%(untrusted comment:)[^\n]*%\1 $PKGURL%" > "$PKGOUT/$PKGIMG.nbz"
}

# description package variables
export PACKAGE=$(pkgline PACKAGE)
export VERSION=$(pkgline VERSION)
export REVISED=$(pkgline REVISED)
export COMMENT=$(pkgline COMMENT)

# support package variables
export CONTACT=$(pkgline CONTACT)
export WEBSITE=$(pkgline WEBSITE)
export BUGTALK=$(pkgline BUGTALK)
export LICENSE=$(pkgline LICENSE)

# related package variables
export REPLACE=$(pkgline REPLACE)
export PROVIDE=$(pkgline PROVIDE)
export REQUIRE=$(pkgline REQUIRE)
export SUGGEST=$(pkgline SUGGEST)
export TOOLING=$(pkgline TOOLING)

# remote package variables
export PKGREPO=$(pkgline PKGREPO)
export PKGSIGN=$(pkgline PKGSIGN)

# TODO: install tooling if needed

# make sure we have the destination directories for this stuff
[ ! -d "$PKGDST" ] && info "Creating source directory... $PKGDST" && mkdir -p "$PKGDST"
[ ! -d "$PKGOUT" ] && info "Creating output directory... $PKGOUT" && mkdir -p "$PKGOUT"

# TODO; use nanolin framework for this setup

# make sure we have keys in the right place to sing stuff
[ ! -e "$PKGOUT/.sign-secret" ] && info "Creating repo signature... $PKGOUT" && signify -G -s "$PKGOUT/.sign-secret" -p "$PKGOUT/signature.pub" -c "$PKGURL"
touch "$PKGDIR/.repo-signatures"
sed "s%^$PKGURL.*%%g;s%$%\n$PKGURL $(tail -1 "$PKGOUT/signature.pub")%" "$PKGDIR/.repo-signatures"

# switch depending on which stage of the package make process
case "$PKGRUN" in
# create source files
SOURCES)
	# do getfile and putfile for all mentioned sources
	grep "^GETFILE" "$PKGDOC" | sed "s%^GETFILE%%g" | runeach getfile || exit 1
	grep "^PUTFILE" "$PKGDOC" | sed "s%^PUTFILE%%g" | runeach putfile || exit 1
	;;
# patch sources
PATCHES)
	# patch each source that is a problem
	grep "^PATCHES" "$PKGDOC" | sed "s%^PATCHED%%g" | runeach patches || exit 1
	;;
# generate license 
LICENSE)
	getlicense
	;;
# do one of these activities
BUILDER|TESTING|INSTALL|REMOVES)
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
	pkgmake testing all
	pkgmake license
	pkgblob
	pkgsign

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
	BUILDER|TESTING|INSTALL|REMOVES|SCRIPTS)
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
		# make sure everything is unmounted beore we try to delete
		umount "$PKGDST/$NLCLI-"*"-overlay" &>/dev/null

		# remove everything from the work dir
		rm -rf "$PKGDST"

		# tell the user what we did
		echo -e "\n\n\tRemoved: $PKGDST\n"
	else
		# tell the user what we didn't do
		echo -e "\n\n\tKeeping: $PKGDST\n"
	fi
	;;
REFRESH)
	# start fresh by cleaning up first
	yes | pkgmake cleanup

	# now make the release from scratch
	pkgmake release
	;;
'')
	# without a special make proceedure do everything
	pkgmake release
	;;
*)
	# when something isn't recognized show usage
	echo "$NLHDR
	Build a $NLSTR Package
	$PKGUSE" && exit 1
	;;
esac 
