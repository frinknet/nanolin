#!/bin/sh

yes | workbox adduser build

add_file /bin/busybox
add_file /bin/signify
add_file /etc/version
add_file /etc/verify.pub

chmod u+s build/bin/busybox
