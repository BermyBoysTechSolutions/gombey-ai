#!/bin/sh
# Verify that the Gombey AI logo and favicon are wired into both app modes.

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOGO_PNG="$ROOT_DIR/assets/logo.png"
LOGO_COPY="$ROOT_DIR/images/gombey_logo.png"
LOGO_SVG="$ROOT_DIR/assets/logo.svg"
FAVICON="$ROOT_DIR/assets/favicon-32x32.png"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for file in "$LOGO_PNG" "$LOGO_COPY" "$LOGO_SVG" "$FAVICON"; do
[ -f "$file" ] || fail "missing branding asset: $file"
done

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

[ "$(hash_file "$LOGO_PNG")" = "$(hash_file "$LOGO_COPY")" ] \
  || fail "images/gombey_logo.png is not the canonical logo asset"

for config in "$ROOT_DIR/librechat.yaml" "$ROOT_DIR/librechat.private.yaml"; do
  grep -Fq 'customLogo: "/images/gombey_logo.png"' "$config" \
    || fail "$config does not use the canonical Gombey AI wordmark"
  grep -Fq 'favicon: "/assets/favicon-32x32.png"' "$config" \
    || fail "$config does not use the dedicated square favicon"
done

grep -Fq 'Gombey AI custom logo sizing/contrast' "$ROOT_DIR/branding/apply-branding.sh" \
  || fail "startup branding CSS is missing"
grep -Fq 'height: auto !important' "$ROOT_DIR/branding/apply-branding.sh" \
  || fail "startup branding CSS can distort the horizontal wordmark"
grep -Fq 'assets/logo.svg' "$ROOT_DIR/branding/apply-branding.sh" \
  || fail "startup branding CSS does not match LibreChat's relative logo URL"

echo "PASS: canonical Gombey AI wordmark, square favicon, and proportional runtime styling are wired for cloud and private modes."
