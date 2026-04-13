#!/bin/bash
# Transpro Network Speed Test - System Info Collector
# Supports macOS and Linux

URL_BASE="https://orlando-g26.github.io/Hardware-Inspection-tool/speedtest-webpage.html"

urlencode() {
    python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1" 2>/dev/null || printf '%s' "$1"
}

OS_TYPE=$(uname -s)

# ---- Hardware ----
if [ "$OS_TYPE" = "Darwin" ]; then
    CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    CORES=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "?")
    THREADS=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "?")
    RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    RAM_GB=$(( RAM_BYTES / 1073741824 ))
    RAM="${RAM_GB} GB"
    OS_VER=$(sw_vers -productVersion 2>/dev/null || echo "")
    OS="macOS ${OS_VER}"
    MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2; exit}')
    [ -z "$MODEL" ] && MODEL=$(sysctl -n hw.model 2>/dev/null || echo "Unknown")

    DEFAULT_IF=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
    if [ -n "$DEFAULT_IF" ] && networksetup -getairportnetwork "$DEFAULT_IF" 2>/dev/null | grep -q "^Current Wi-Fi"; then
        SSID=$(networksetup -getairportnetwork "$DEFAULT_IF" 2>/dev/null | sed 's/Current Wi-Fi Network: //')
        NET_TYPE="Wi-Fi - ${SSID}"
    elif [ -n "$DEFAULT_IF" ]; then
        NET_TYPE="Ethernet"
    else
        NET_TYPE="Unknown"
    fi
    NET_SPEED="Unknown"
    OPEN_CMD="open"

elif [ "$OS_TYPE" = "Linux" ]; then
    CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //' | xargs || echo "Unknown")
    CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo "?")
    THREADS=$CORES
    RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    RAM_GB=$(( ${RAM_KB:-0} / 1048576 ))
    RAM="${RAM_GB} GB"
    OS=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}" || uname -o 2>/dev/null || echo "Linux")
    MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null | xargs || echo "Unknown")

    DEFAULT_IF=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
    if [ -n "$DEFAULT_IF" ]; then
        SSID=$(iwgetid -r "$DEFAULT_IF" 2>/dev/null || \
               nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 || echo "")
        if [ -n "$SSID" ]; then
            NET_TYPE="Wi-Fi - ${SSID}"
        else
            NET_TYPE="Ethernet"
        fi
        SPEED_RAW=$(cat /sys/class/net/${DEFAULT_IF}/speed 2>/dev/null || echo "")
        if [ -n "$SPEED_RAW" ] && [ "$SPEED_RAW" -gt 0 ] 2>/dev/null; then
            if [ "$SPEED_RAW" -ge 1000 ]; then
                NET_SPEED="$(( SPEED_RAW / 1000 )) Gbps"
            else
                NET_SPEED="${SPEED_RAW} Mbps"
            fi
        else
            NET_SPEED="Unknown"
        fi
    else
        NET_TYPE="Unknown"
        NET_SPEED="Unknown"
    fi
    OPEN_CMD="xdg-open"

else
    echo "Unsupported OS: $OS_TYPE"
    exit 1
fi

CPU_FULL="${CPU} (${CORES}C / ${THREADS}T)"

# ---- Build URL ----
QUERY="hwready=1"
QUERY="${QUERY}&cpu=$(urlencode "${CPU_FULL}")"
QUERY="${QUERY}&ram=$(urlencode "${RAM}")"
QUERY="${QUERY}&os=$(urlencode "${OS}")"
QUERY="${QUERY}&model=$(urlencode "${MODEL:-Unknown}")"
QUERY="${QUERY}&netType=$(urlencode "${NET_TYPE}")"
QUERY="${QUERY}&netSpeed=$(urlencode "${NET_SPEED}")"

"$OPEN_CMD" "${URL_BASE}?${QUERY}"
