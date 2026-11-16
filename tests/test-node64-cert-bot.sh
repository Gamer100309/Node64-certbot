#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT="$(cd -- "$(dirname -- "$0")/.." && pwd)/node64-cert-bot"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

bash -n "$SCRIPT" || fail "bash -n"
pass "Bash syntax"

out="$("$SCRIPT" version)"
[[ "$out" == "Node64 Cert Bot 0.6.0" ]] || fail "version without config"
pass "version works without API configuration"

mkdir -p "$TMP/etc/certs"
chmod 700 "$TMP/etc" "$TMP/etc/certs"
cat > "$TMP/etc/certs/good.conf" <<'CONF'
NAME="sample"
CERT_ID="123"
CERT_HOSTNAME="example.org"
CONF
chmod 600 "$TMP/etc/certs/good.conf"
out="$(NODE64_CERT_BOT_CONFIG_DIR="$TMP/etc" "$SCRIPT" list)"
[[ "$out" == *"sample"* && "$out" == *"123"* ]] || fail "list with valid config"
pass "list works without API credentials"

chmod 644 "$TMP/etc/certs/good.conf"
if NODE64_CERT_BOT_CONFIG_DIR="$TMP/etc" "$SCRIPT" list >/dev/null 2>&1; then fail "insecure config permissions accepted"; fi
chmod 600 "$TMP/etc/certs/good.conf"
pass "rejects group/world-readable executable config"

NODE64_CERT_BOT_TEST_SOURCE_ONLY=1 source "$SCRIPT"
mkdir -p "$TMP/extract-good" "$TMP/extract-bad" "$TMP/extract-link"
python3 - "$TMP" <<'PY'
import os, stat, sys, zipfile
root=sys.argv[1]
with zipfile.ZipFile(root+'/good.zip','w') as z:
    z.writestr('bundle/cert.pem','certificate')
with zipfile.ZipFile(root+'/bad.zip','w') as z:
    z.writestr('../escape.txt','escape')
with zipfile.ZipFile(root+'/link.zip','w') as z:
    i=zipfile.ZipInfo('bundle/link')
    i.create_system=3
    i.external_attr=(stat.S_IFLNK|0o777)<<16
    z.writestr(i,'/etc/passwd')
PY
result="$(safe_extract "$TMP/good.zip" "$TMP/extract-good")"
[[ -s "$result/cert.pem" ]] || fail "valid ZIP not extracted"
pass "extracts a valid archive"
if (safe_extract "$TMP/bad.zip" "$TMP/extract-bad") >/dev/null 2>&1; then fail "path traversal ZIP accepted"; fi
pass "rejects ZIP path traversal"
if (safe_extract "$TMP/link.zip" "$TMP/extract-link") >/dev/null 2>&1; then fail "ZIP symlink accepted"; fi
pass "rejects ZIP symlinks"


# Exact fullchain composition: leaf certificate followed by the complete chain.
mkdir -p "$TMP/chain"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/chain/leaf.key" -out "$TMP/chain/leaf.pem" -subj "/CN=leaf.example.org" -days 2 >/dev/null 2>&1
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/chain/intermediate.key" -out "$TMP/chain/intermediate.pem" -subj "/CN=intermediate.example.org" -days 2 >/dev/null 2>&1
cp "$TMP/chain/leaf.pem" "$TMP/chain/cert.pem"
cp "$TMP/chain/intermediate.pem" "$TMP/chain/chain.pem"
cat "$TMP/chain/cert.pem" "$TMP/chain/chain.pem" > "$TMP/chain/fullchain.pem"
validate_chain_layout "$TMP/chain/cert.pem" "$TMP/chain/chain.pem" "$TMP/chain/fullchain.pem" || fail "valid fullchain layout rejected"
pass "accepts exact leaf-plus-chain fullchain layout"
cat "$TMP/chain/chain.pem" "$TMP/chain/cert.pem" > "$TMP/chain/wrong.pem"
if (validate_chain_layout "$TMP/chain/cert.pem" "$TMP/chain/chain.pem" "$TMP/chain/wrong.pem") >/dev/null 2>&1; then fail "wrong fullchain order accepted"; fi
pass "rejects incorrect fullchain certificate order"
cat "$TMP/chain/cert.pem" > "$TMP/chain/incomplete.pem"
if (validate_chain_layout "$TMP/chain/cert.pem" "$TMP/chain/chain.pem" "$TMP/chain/incomplete.pem") >/dev/null 2>&1; then fail "incomplete fullchain accepted"; fi
pass "rejects incomplete fullchain"

# Deployment path components must not traverse symlinks or writable folders.
mkdir -p "$TMP/path-safe/root"
chmod 700 "$TMP/path-safe" "$TMP/path-safe/root"
secure_root_path "$TMP/path-safe/root" no
ln -s "$TMP/path-safe/root" "$TMP/path-safe/link"
if (secure_root_path "$TMP/path-safe/link/child" yes) >/dev/null 2>&1; then fail "symlink in deployment path accepted"; fi
pass "rejects symlinked deployment path components"
mkdir -p "$TMP/path-safe/writable"
chmod 777 "$TMP/path-safe/writable"
if (secure_root_path "$TMP/path-safe/writable/child" yes) >/dev/null 2>&1; then fail "world-writable deployment path accepted"; fi
pass "rejects group/world-writable deployment path components"

# Batch isolation: one failed certificate must not prevent the next one running.
mkdir -p "$TMP/batch/certs" "$TMP/batch-state"
chmod 700 "$TMP/batch" "$TMP/batch/certs" "$TMP/batch-state"
printf 'API_BASE_URL="https://node64.example.invalid"\nAPI_CURL_CONFIG="%s/api.curl"\nAPI_CA_FILE="/etc/ssl/certs/ca-certificates.crt"\nCERT_ROOT="%s/releases"\n' "$TMP" "$TMP" > "$TMP/batch/config"
: > "$TMP/api.curl"
chmod 600 "$TMP/batch/config" "$TMP/api.curl"
cat > "$TMP/batch/certs/one.conf" <<'CONF'
CERT_ID="101"
CERT_HOSTNAME="one.example.org"
CONF
cat > "$TMP/batch/certs/two.conf" <<'CONF'
CERT_ID="102"
CERT_HOSTNAME="two.example.org"
CONF
chmod 600 "$TMP/batch/certs/one.conf" "$TMP/batch/certs/two.conf"
set +e
batch_out="$(NODE64_CERT_BOT_CONFIG_DIR="$TMP/batch" NODE64_CERT_BOT_STATE_DIR="$TMP/batch-state" "$SCRIPT" sync 2>&1)"
batch_status=$?
set -e
(( batch_status != 0 )) || fail "invalid batch unexpectedly succeeded"
[[ "$batch_out" == *"one.conf"* && "$batch_out" == *"two.conf"* ]] || fail "batch did not report both certificate failures"
pass "continues batch processing after an individual certificate failure"


# Release retention preserves newest N plus current even if current is old.
mkdir -p "$TMP/retention/releases"
chmod 700 "$TMP/retention" "$TMP/retention/releases"
ids=( $(printf '%064x\n' 1 2 3 4) )
for i in 0 1 2 3; do
  mkdir "$TMP/retention/releases/${ids[$i]}"
  chmod 755 "$TMP/retention/releases/${ids[$i]}"
  touch -d "$((4 - i)) minutes ago" "$TMP/retention/releases/${ids[$i]}"
done
ln -s "$TMP/retention/releases/${ids[0]}" "$TMP/retention/current"
prune_releases "$TMP/retention" 2
[[ -d "$TMP/retention/releases/${ids[0]}" ]] || fail "active old release was pruned"
[[ -d "$TMP/retention/releases/${ids[2]}" && -d "$TMP/retention/releases/${ids[3]}" ]] || fail "newest releases were pruned"
[[ ! -e "$TMP/retention/releases/${ids[1]}" ]] || fail "obsolete release was not pruned"
pass "retention keeps newest releases and protects active release"

# Atomic current switch and rollback behavior.
mkdir -p "$TMP/rollback/releases/old" "$TMP/rollback/releases/new"
ln -s "$TMP/rollback/releases/old" "$TMP/rollback/current"
previous="$(readlink "$TMP/rollback/current")"
switch_current "$TMP/rollback" "$TMP/rollback/releases/new"
[[ "$(readlink -f "$TMP/rollback/current")" == "$TMP/rollback/releases/new" ]] || fail "new release was not activated"
restore_current "$TMP/rollback" "$previous"
[[ "$(readlink -f "$TMP/rollback/current")" == "$TMP/rollback/releases/old" ]] || fail "previous release was not restored"
pass "atomic activation and rollback restore previous release"


# A failed deployment reload restores the previous release and retries reload.
mkdir -p "$TMP/rollback-retry/releases/old" "$TMP/rollback-retry/releases/new"
ln -s "$TMP/rollback-retry/releases/new" "$TMP/rollback-retry/current"
marker="$TMP/rollback-retry/reload-once"
reload_cmd="if [[ ! -e '$marker' ]]; then touch '$marker'; exit 1; else exit 0; fi"
if bash -c "$reload_cmd"; then fail "initial reload simulation unexpectedly succeeded"; fi
if rollback_after_reload_failure "$TMP/rollback-retry" "$TMP/rollback-retry/releases/old" "$reload_cmd" "retry-test"; then
  :
else
  fail "rollback reload retry failed unexpectedly"
fi
[[ "$(readlink -f "$TMP/rollback-retry/current")" == "$TMP/rollback-retry/releases/old" ]] || fail "rollback retry did not restore old current"
[[ -e "$marker" ]] || fail "rollback reload command was not executed"
pass "reload failure restores previous release and retries service reload"
