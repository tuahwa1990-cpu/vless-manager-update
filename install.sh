#!/bin/sh
# VLESS Manager Pro - pemasang pertama (OpenWrt)
BASE="https://raw.githubusercontent.com/tuahwa1990-cpu/vless-manager-update/main"
say() { echo ">> $1"; }
die() { echo "RALAT: $1"; exit 1; }

[ "$(id -u)" = "0" ] || die "mesti dijalankan sebagai root"
[ -f /etc/openwrt_release ] || die "ini bukan OpenWrt"

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  else wget -q -O "$2" "$1"; fi
}

say "Memasang pakej yang diperlukan..."
PK="sing-box kmod-nft-tproxy kmod-tun ip-full curl ca-bundle usign ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus ucode-mod-digest nftables-json uhttpd-mod-ubus"
if command -v apk >/dev/null 2>&1; then
  apk update >/dev/null 2>&1
  for p in $PK; do apk add "$p" >/dev/null 2>&1 || echo "   amaran: $p tidak dipasang"; done
elif command -v opkg >/dev/null 2>&1; then
  opkg update >/dev/null 2>&1
  for p in $PK; do opkg install "$p" >/dev/null 2>&1 || echo "   amaran: $p tidak dipasang"; done
else
  die "tiada apk atau opkg"
fi
command -v sing-box >/dev/null 2>&1 || die "sing-box gagal dipasang"
command -v usign >/dev/null 2>&1 || die "usign gagal dipasang"

say "Memuat turun VLESS Manager Pro..."
T=/tmp/vfull
rm -rf "$T"; mkdir -p "$T/x"
fetch "$BASE/full-latest.txt" "$T/latest.txt" || die "gagal memuat turun maklumat versi"
VER=$(sed -n 's/^version=//p' "$T/latest.txt" | tr -d ' \r\n')
SHA=$(sed -n 's/^sha256=//p' "$T/latest.txt" | tr -d ' \r\n')
[ -n "$VER" ] && [ -n "$SHA" ] || die "maklumat versi tidak sah"
fetch "$BASE/vless-full-$VER.tar.gz" "$T/p.tgz" || die "gagal memuat turun pakej"
[ "$(sha256sum "$T/p.tgz" | cut -d' ' -f1)" = "$SHA" ] || die "semakan sha256 gagal, pemasangan dibatalkan"

say "Memasang fail..."
tar xzf "$T/p.tgz" -C "$T/x" || die "gagal mengekstrak"
[ -d "$T/x/files" ] || die "pakej tidak sah"
( cd "$T/x/files" && find . -type f ) | while read -r f; do
  d="/${f#./}"
  mkdir -p "$(dirname "$d")"
  cp -p "$T/x/files/${f#./}" "$d"
done
chmod +x /etc/vless-manager/*.sh /overlay/vless-manager-pro-v3/*.sh /overlay/vless-manager-pro-v3/modules/*/*.sh /usr/libexec/vless-* /www/cgi-bin/vless-* /etc/init.d/vless-manager /etc/init.d/vless-watchdog 2>/dev/null
mkdir -p /etc/vless-manager/nodes
chmod 700 /etc/vless-manager/nodes
mkdir -p /overlay/vless-manager-pro-v3/config/usage /overlay/vless-manager-pro-v3/runtime /overlay/vless-manager-pro-v3/backup
echo "$VER" > /etc/vless-manager/app-version

say "Menyediakan jadual tugas..."
CR=/etc/crontabs/root
touch "$CR"
addcron() { grep -qF "$1" "$CR" || echo "$2 $1" >> "$CR"; }
addcron "/bin/sh /overlay/vless-manager-pro-v3/recovery-run.sh" "* * * * *"
addcron "/bin/sh /overlay/vless-manager-pro-v3/autoswitch-run.sh" "* * * * *"
addcron "/bin/sh /overlay/vless-manager-pro-v3/sync-nodes.sh" "*/5 * * * *"
addcron "/usr/libexec/vless-usage-tick" "* * * * *"
addcron "/usr/libexec/vless-tunnel-tick" "*/5 * * * *"
/etc/init.d/cron enable 2>/dev/null
/etc/init.d/cron restart 2>/dev/null

say "Menyediakan permulaan automatik..."
[ -f /etc/rc.local ] || printf '%s\n' 'exit 0' > /etc/rc.local
if ! grep -q 'vless-manager/global-control.sh' /etc/rc.local; then
  grep -v '^exit 0' /etc/rc.local > /tmp/rc.new
  echo '[ -f /etc/vless-manager/global-enabled ] && sh /etc/vless-manager/global-control.sh on' >> /tmp/rc.new
  echo 'exit 0' >> /tmp/rc.new
  cat /tmp/rc.new > /etc/rc.local
  rm -f /tmp/rc.new
fi
/etc/init.d/vless-manager enable 2>/dev/null
/etc/init.d/vless-watchdog enable 2>/dev/null
/etc/init.d/vless-watchdog restart 2>/dev/null

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null
/etc/init.d/uhttpd restart 2>/dev/null
rm -rf "$T"

echo ""
echo "=============================================="
echo " VLESS Manager Pro $VER siap dipasang."
echo " Hardware ID router ini:"
echo "   $(/usr/libexec/vless-licchk --id)"
echo ""
echo " Buka laman LuCI router, pergi ke"
echo " Services > VLESS Manager, dan hantar Hardware ID"
echo " ini kepada pembekal untuk mendapatkan kunci lesen."
echo "=============================================="
