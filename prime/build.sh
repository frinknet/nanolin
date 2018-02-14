#!/bin/sh

add_file /bin/busybox
add_file /etc/version
add_file /etc/verify.pub

workbox sh
workroot asp checkout signify
workbox sh -c eval "
"

chmod u+s build/bin/busybox
