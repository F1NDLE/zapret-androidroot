#!/system/bin/sh
MODDIR="/data/adb/modules/zapret"
BIN="$MODDIR/bin/nfqws"
LISTS="$MODDIR/common"
CONF="$LISTS/config.txt"
STRAT_FILE="$MODDIR/strategy.txt"
LOG="$MODDIR/logs.log"

echo "[$(date)] START" > "$LOG"
chmod 755 "$BIN"

STRAT_NUM=$(cat "$STRAT_FILE" 2>/dev/null | tr -d '\r' | xargs)
[ -z "$STRAT_NUM" ] && STRAT_NUM="1"

RAW_STRAT=$(grep "^$STRAT_NUM " "$CONF" | sed "s/^$STRAT_NUM //" | tr -d '\r')

if [ -z "$RAW_STRAT" ]; then
    echo "Error: Strategy №$STRAT_NUM not found" >> "$LOG"
    exit 1
fi

FINAL_ARGS=$(echo "$RAW_STRAT" | sed \
    -e "s|{ipset}|$LISTS/ipset.txt|g" \
    -e "s|{whitelist}|$LISTS/whitelist.txt|g" \
    -e "s|{ignore}|$LISTS/ignore.txt|g" \
    -e "s|{hosts}|$LISTS/autohosts.txt|g" \
    -e "s|{quicgoogle}|$LISTS/quic_initial_www_google_com.bin|g" \
    -e "s|{tlsgoogle}|$LISTS/quic_initial_www_google_com.bin|g")

killall nfqws >/dev/null 2>&1
iptables -t mangle -S POSTROUTING | grep "NFQUEUE" | sed 's/-A/-D/' | while read line; do iptables -t mangle $line >/dev/null 2>&1; done

iptables -t mangle -A POSTROUTING -p tcp -m multiport --dports 80,443,2053,2083,2087,2096,8443 -j NFQUEUE --queue-num 200 --queue-bypass
iptables -t mangle -A POSTROUTING -p udp -m multiport --dports 443,19294:19344,50000:50100 -j NFQUEUE --queue-num 200 --queue-bypass

eval "$BIN --qnum=200 --user=root $FINAL_ARGS" >> "$LOG" 2>&1 &
