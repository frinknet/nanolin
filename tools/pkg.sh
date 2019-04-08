#create $PKGRND
PKGRND=/tmp/$PKGSTR-$RANDOM-$USER-sign.tmp
PKGURL=https://repo.frinknet.com/
PKGSIG="$PKGDIR/.repo-signatures"
PKGDIR=/var/packages
PKGBIN="$PKGDIR/busybox.pkg"



# create tar
tar -C pkg/ -czf $PKGRND .

# sign the tar and replace comment
signify -Sz -s verify.sec -m $PKGRND -x -|sed -r "s%(untrusted comment:)[^\n]*%\1 $PKGURL%" > "$PKGBIN"

# remove temp file
rm $PKGRND

# get signature
PKGVFY=$(sed -rn "s%($(sed -rn "s/.*untrusted comment: ([^\n]*)/\1/p" "$PKGBIN")) ([^\n]*)%untrusted comment: \1\n\2%p" $PKGSIG)

# list parts of file
echo "$PKGVFY" | signify -Vz -p - -x "$PKGBIN" | tar tzf -

# list files in overlay
echo "$PKGVFY" | signify -Vz -p - -x "$PKGBIN" | tar Oxzf - | tar tjf -

# xtract files in overlay to $PKGDST
echo "$PKGVFY" | signify -Vz -p - -x "$PKGBIN" | tar Oxzf - overlay.bz | tar -C $PKGDST xjf -


# extract manifest
tar Oxzf "$PKGBIN" manifest.bz | bzcat > $PKGDIR/.manifest/

# extract recipe
tar Oxzf "$PKGBIN" recipe.bz | bzcat > $PKGDIR/.packages/


