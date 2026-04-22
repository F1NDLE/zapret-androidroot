#!/system/bin/sh
MODDIR="/data/adb/modules/zapret"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done


if [ -f "$MODDIR/autostart" ]; then
    /system/bin/sh "$MODDIR/action.sh" > /dev/null 2>&1
fi
