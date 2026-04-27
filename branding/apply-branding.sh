#!/bin/sh
# Apply Gombey AI white-label text to static frontend files at container startup.
# This catches default title/meta/manifest/bundle strings that are baked into the upstream image.

set -eu

BRAND_NAME="Gombey AI"
BRAND_DESCRIPTION="Gombey AI - Private AI chat for your business"

TARGET_DIRS="/app/client/dist /app/client/public"

for dir in $TARGET_DIRS; do
  [ -d "$dir" ] || continue
  find "$dir" -type f \( -name '*.html' -o -name '*.js' -o -name '*.webmanifest' -o -name '*.json' \) -print0 \
    | xargs -0 sed -i \
      -e "s/LibreChat - An open source chat application with support for multiple AI models/$BRAND_DESCRIPTION/g" \
      -e "s/LibreChat/$BRAND_NAME/g" \
      -e "s/librechat/gombey-ai/g" \
      -e "s/ChatGPT Clone/Gombey AI/g" 2>/dev/null || true
done


# Make branding visible on the login screen and copy mounted assets into the built frontend.
if [ -f /app/client/public/assets/logo.png ]; then
  cp /app/client/public/assets/logo.png /app/client/dist/assets/logo.png 2>/dev/null || true
fi
if [ -f /app/client/public/assets/logo.svg ]; then
  cp /app/client/public/assets/logo.svg /app/client/dist/assets/logo.svg 2>/dev/null || true
fi
for icon in favicon-16x16.png favicon-32x32.png icon-192x192.png maskable-icon.png apple-touch-icon-180x180.png; do
  [ -f "/app/client/public/assets/$icon" ] && cp "/app/client/public/assets/$icon" "/app/client/dist/assets/$icon" 2>/dev/null || true
done
find /app/client/dist -type f \( -name 'locales.*.js' -o -name 'index.*.js' \) -print0 2>/dev/null \
  | xargs -0 sed -i -e 's/Welcome back/Welcome back to Gombey AI/g' 2>/dev/null || true


# Make the custom logo larger and readable in light mode while staying transparent in dark mode.
for css in /app/client/dist/assets/index.*.css; do
  [ -f "$css" ] || continue
  grep -q 'Gombey AI custom logo sizing' "$css" && continue
  cat >> "$css" <<'CSS'
/* Gombey AI custom logo sizing/contrast */
img[src*="gombey_logo"], img[src*="/assets/logo"] {
  width: 260px !important;
  height: 260px !important;
  max-width: 260px !important;
  max-height: 260px !important;
  object-fit: contain !important;
}
html:not(.dark) img[src*="gombey_logo"], html:not(.dark) img[src*="/assets/logo"] {
  border-radius: 32px !important;
  background: linear-gradient(135deg, #0a0e18 0%, #1a2030 100%) !important;
  padding: 16px !important;
  box-shadow: 0 6px 30px rgba(0,0,0,0.28) !important;
}
html.dark img[src*="gombey_logo"], html.dark img[src*="/assets/logo"], .dark img[src*="gombey_logo"], .dark img[src*="/assets/logo"] {
  background: transparent !important;
  box-shadow: none !important;
  padding: 0 !important;
}
CSS
done

echo "Gombey AI branding applied."
