#!/bin/sh

inc_file /usr/bin/copymark

inc_script busybox
inc_script signify
#inc_script linux

#add_file /etc/version
#add_file /etc/verify.pub

info "we did it!"

exit 1
rm -rf build

#
