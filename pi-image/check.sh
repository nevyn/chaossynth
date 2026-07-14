#!/usr/bin/env bash
# check.sh -- the one runnable check for pi-image/: lints every script
# (including the remote half of provision.sh, which hides in a heredoc)
# and exercises prepare-sd.sh against a fake bootfs. No SD card, no
# network, no sudo needed. Exits non-zero loudly if the logic broke.
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "FAIL: $*" >&2; exit 1; }
SCRIPTS=(prepare-sd.sh provision.sh deploy.sh overlayfs.sh check.sh)

for s in "${SCRIPTS[@]}"; do
  bash -n "$s" || fail "$s does not parse"
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The remote script inside provision.sh's quoted heredoc is invisible to
# the linter -- extract it and lint it separately.
{
  echo '#!/bin/bash'
  sed -n "/<<'REMOTE'/,/^REMOTE\$/p" provision.sh | sed '1d;$d'
} >"$TMP/provision-remote.sh"
[ "$(wc -l <"$TMP/provision-remote.sh")" -gt 10 ] || fail "could not extract remote script from provision.sh"
bash -n "$TMP/provision-remote.sh" || fail "provision.sh remote script does not parse"

if command -v shellcheck >/dev/null; then
  shellcheck "${SCRIPTS[@]}" || fail "shellcheck findings in scripts"
  shellcheck "$TMP/provision-remote.sh" || fail "shellcheck findings in provision.sh remote script"
else
  echo "note: shellcheck not installed (brew install shellcheck) -- lint skipped"
fi

# --- prepare-sd.sh against a fake bootfs ------------------------------------
BOOT="$TMP/bootfs"
mkdir -p "$BOOT"
touch "$BOOT/config.txt" "$BOOT/bcm2711-rpi-4-b.dtb"
printf 'console=serial0,115200 console=tty1 root=PARTUUID=deadbeef-02 rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspi-config/init_resize.sh\n' >"$BOOT/cmdline.txt"

echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeFakeFakeFakeFakeFakeFakeFakeFakeFakeFake test@example" >"$TMP/key.pub"
cat >"$TMP/secrets.env" <<EOF
WIFI_COUNTRY=SE
WIFI1_SSID=homenet
WIFI1_PSK=password1
WIFI2_SSID='hotspot net'
WIFI2_PSK=password2
CHAOS_USER=chaos
CHAOS_PASSWORD='correct horse battery'
SSH_PUBKEY_PATH=$TMP/key.pub
EOF

run() { SECRETS_FILE="$TMP/secrets.env" ./prepare-sd.sh "$BOOT"; }

run >/dev/null || fail "prepare-sd.sh failed on a valid bootfs"
[ -f "$BOOT/firstrun.sh" ] || fail "no firstrun.sh written"
bash -n "$BOOT/firstrun.sh" || fail "generated firstrun.sh does not parse"
grep -q 'systemd.run=/boot/firstrun.sh' "$BOOT/cmdline.txt" || fail "cmdline.txt hook missing"
[ "$(wc -l <"$BOOT/cmdline.txt")" -eq 1 ] || fail "cmdline.txt is no longer a single line"
grep -q '^ssid=homenet$' "$BOOT/firstrun.sh" || fail "wifi1 missing from firstrun.sh"
grep -q '^ssid=hotspot net$' "$BOOT/firstrun.sh" || fail "wifi2 (ssid with space) missing from firstrun.sh"
grep -q "set_hostname 'chaossynth'" "$BOOT/firstrun.sh" || fail "hostname missing from firstrun.sh"
grep -qF 'ssh-ed25519 AAAA' "$BOOT/firstrun.sh" || fail "ssh pubkey missing from firstrun.sh"
# shellcheck disable=SC2016  # a literal $6$ is exactly what we want
grep -qF '$6$' "$BOOT/firstrun.sh" || fail "no SHA512-crypt password hash in firstrun.sh"

# The hash is full of $-signs; make sure it survives shell expansion in the
# generated chpasswd fallback (run that line with chpasswd stubbed out).
expected_hash=$(grep -o $'[$]6[$][^\']*' "$BOOT/firstrun.sh" | head -n1)
chpw_line=$(grep 'chpasswd -e$' "$BOOT/firstrun.sh")
emitted=$(bash -c "chpasswd() { cat; }; FIRSTUSER=pi; $chpw_line")
[ "$emitted" = "pi:$expected_hash" ] || fail "password hash gets mangled by expansion in the chpasswd line: $emitted"
grep -qF 'correct horse battery' "$BOOT/firstrun.sh" && fail "PLAINTEXT PASSWORD leaked into firstrun.sh" || true

# re-run must not duplicate the cmdline hook
run >/dev/null || fail "prepare-sd.sh failed on re-run"
[ "$(grep -o 'systemd\.run=' "$BOOT/cmdline.txt" | grep -c .)" -eq 1 ] || fail "cmdline hook duplicated on re-run"

# --- refusals ----------------------------------------------------------------
SECRETS_FILE="$TMP/secrets.env" ./prepare-sd.sh "$TMP" >/dev/null 2>&1 && fail "accepted a dir that is not a bootfs" || true
SECRETS_FILE="$TMP/nope.env" ./prepare-sd.sh "$BOOT" >/dev/null 2>&1 && fail "ran without secrets.env" || true

sed 's/password1/changeme/' "$TMP/secrets.env" >"$TMP/lazy.env"
SECRETS_FILE="$TMP/lazy.env" ./prepare-sd.sh "$BOOT" >/dev/null 2>&1 && fail "accepted a 'changeme' secret" || true

sed "s/homenet/o'brien/" "$TMP/secrets.env" >"$TMP/quote.env"
SECRETS_FILE="$TMP/quote.env" ./prepare-sd.sh "$BOOT" >/dev/null 2>&1 && fail "accepted a single-quoted SSID (would break the generated script)" || true

sed 's/password1/short/' "$TMP/secrets.env" >"$TMP/short.env"
SECRETS_FILE="$TMP/short.env" ./prepare-sd.sh "$BOOT" >/dev/null 2>&1 && fail "accepted a too-short WPA psk" || true

echo "PASS: pi-image checks green"
