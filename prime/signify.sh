#!/bin/sh
asp checkout signify
chmod 777 signify -R

cd /signify/trunk

export LDFLAGS='-static'
su build -c 'makepkg -f'

cp pkg/signify/usr/bin/signify /usr/bin/
