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

echo "Gombey AI branding applied."
