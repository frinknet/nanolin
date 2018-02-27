#!/bin/sh

add_file /bin/busybox
add_file /etc/version
add_file /etc/verify.pub

yes | workbox adduser build

info starting signify build
workrun build/signify.sh

rem_file /signify.sh
add_file /bin/signify

chmod u+s build/bin/busybox
