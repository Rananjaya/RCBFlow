#!/usr/bin/env bash
# Verifies an Android APK before it is released.
#
# Usage: verify_apk.sh <apk> <expected-application-id> [expected-cert-sha256]
#
# Checks:
#   - the package name equals <expected-application-id>;
#   - android.permission.INTERNET is not requested;
#   - the signature verifies (apksigner);
#   - if [expected-cert-sha256] is given (hex, colons optional, any case), the
#     signer's certificate SHA-256 matches it. This catches a build accidentally
#     signed with the debug key.
#   - if EXPECTED_VERSION_NAME / EXPECTED_VERSION_CODE are set, they match.
#
# Uses aapt2 and apksigner from the newest Android build-tools under
# $ANDROID_HOME (or $ANDROID_SDK_ROOT).
set -euo pipefail

APK="${1:?apk path required}"
APP_ID="${2:?expected application id required}"
EXPECTED_CERT="${3:-}"

fail() { echo "::error title=APK verification::$*"; echo "APK verification failed: $*" >&2; exit 1; }

[[ -f "$APK" ]] || fail "APK not found: $APK"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[[ -n "$SDK" && -d "$SDK/build-tools" ]] || fail "Android SDK build-tools not found (set ANDROID_HOME)"

# Newest build-tools directory, comparing version components numerically.
BT=""
for d in "$SDK"/build-tools/*/; do
  d="${d%/}"
  [[ -x "$d/aapt2" && -x "$d/apksigner" ]] || continue
  if [[ -z "$BT" ]]; then BT="$d"; continue; fi
  newer="$(printf '%s\n%s\n' "$(basename "$BT")" "$(basename "$d")" \
    | awk -F'[.-]' '{printf "%05d%05d%05d %s\n", $1, $2, $3, $0}' | sort | tail -n1 | cut -d' ' -f2)"
  [[ "$newer" == "$(basename "$d")" ]] && BT="$d"
done
[[ -n "$BT" ]] || fail "no build-tools with aapt2 and apksigner found under $SDK/build-tools"
echo "Using build-tools: $(basename "$BT")"

BADGING="$("$BT/aapt2" dump badging "$APK")"
PKG_LINE="$(printf '%s\n' "$BADGING" | grep -m1 '^package:')"
PKG="$(printf '%s\n' "$PKG_LINE" | sed -n "s/.* name='\([^']*\)'.*/\1/p")"
VNAME="$(printf '%s\n' "$PKG_LINE" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"
VCODE="$(printf '%s\n' "$PKG_LINE" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")"

[[ "$PKG" == "$APP_ID" ]] || fail "package is '$PKG', expected '$APP_ID'"
echo "OK: package $PKG (versionName $VNAME, versionCode $VCODE)"

if [[ -n "${EXPECTED_VERSION_NAME:-}" && "$VNAME" != "$EXPECTED_VERSION_NAME" ]]; then
  fail "versionName is '$VNAME', expected '$EXPECTED_VERSION_NAME'"
fi
if [[ -n "${EXPECTED_VERSION_CODE:-}" && "$VCODE" != "$EXPECTED_VERSION_CODE" ]]; then
  fail "versionCode is '$VCODE', expected '$EXPECTED_VERSION_CODE'"
fi

if printf '%s\n' "$BADGING" | grep -q "uses-permission: name='android.permission.INTERNET'"; then
  fail "APK requests android.permission.INTERNET (not allowed in release builds; see PRIVACY_AND_SECURITY.md)"
fi
echo "OK: no INTERNET permission"

CERTS="$("$BT/apksigner" verify --print-certs "$APK")" || fail "apksigner could not verify the signature"
SIGNERS="$(printf '%s\n' "$CERTS" | grep -c '^Signer #[0-9]* certificate SHA-256 digest:' || true)"
[[ "$SIGNERS" == 1 ]] || fail "expected exactly 1 signer, found $SIGNERS"
ACTUAL_CERT="$(printf '%s\n' "$CERTS" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')"
SUBJECT="$(printf '%s\n' "$CERTS" | sed -n 's/^Signer #1 certificate DN: //p')"
echo "OK: signature verifies (signer: $SUBJECT)"
echo "Signer certificate SHA-256: $ACTUAL_CERT"

if [[ -n "$EXPECTED_CERT" ]]; then
  want="$(printf '%s' "$EXPECTED_CERT" | tr -d ':[:space:]' | tr 'A-F' 'a-f')"
  [[ "$ACTUAL_CERT" == "$want" ]] \
    || fail "signing certificate $ACTUAL_CERT does not match the expected release certificate $want"
  echo "OK: signed with the expected release certificate"
fi
