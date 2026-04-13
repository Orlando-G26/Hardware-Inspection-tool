#!/bin/bash
# Transpro Network Speed Test - macOS System Info Collector
# Double-click to run — opens Terminal automatically

URL_BASE="https://orlando-g26.github.io/Hardware-Inspection-tool/speedtest-webpage.html"

urlencode() {
    python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1" 2>/dev/null || printf '%s' "$1"
}

CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
CORES=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "?")
THREADS=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "?")
CPU_FULL="${CPU} (${CORES}C / ${THREADS}T)"

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

QUERY="hwready=1"
QUERY="${QUERY}&cpu=$(urlencode "${CPU_FULL}")"
QUERY="${QUERY}&ram=$(urlencode "${RAM}")"
QUERY="${QUERY}&os=$(urlencode "${OS}")"
QUERY="${QUERY}&model=$(urlencode "${MODEL}")"
QUERY="${QUERY}&netType=$(urlencode "${NET_TYPE}")"
QUERY="${QUERY}&netSpeed=Unknown"

open "${URL_BASE}?${QUERY}"
