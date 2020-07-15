#!/bin/sh

cp -r /tmp/aliddns-plus/* /koolshare/
chmod a+x /koolshare/scripts/aliddns-plus_*

# add icon into softerware center
dbus set softcenter_module_aliddns-plus_install=1
dbus set softcenter_module_aliddns-plus_version=0.4
dbus set softcenter_module_aliddns-plus_description="阿里云解析自动更新IP"
