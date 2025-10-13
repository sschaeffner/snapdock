#!/bin/bash

mkdir /run/dbus
ls -al /run
rm -rf /run/dbus/pid
dbus-daemon --system --nosyslog --print-address
avahi-daemon --no-drop-root --no-chroot --no-rlimits --daemonize
/app/snapserver