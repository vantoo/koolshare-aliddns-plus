#!/bin/sh

if [ "`dbus get aliddns-plus_enable`" = "1" ]; then
    dbus delay aliddns-plus_timer `dbus get aliddns_interval` /koolshare/scripts/aliddns-plus_update.sh
else
    dbus remove __delay__aliddns-plus_timer
fi
