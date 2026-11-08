#!/usr/bin/env bash
#
# Builds signed release APKs of Cariño, one per ABI.
#
# Reads the keystore and passwords from .env at the repo root (gitignored;
# see .env.example). The keystore is stored there base64-encoded. This
# script decodes it to a temporary file for the build only and deletes it
# afterwards. Nothing secret is printed.
#
# android/app/build.gradle.kts reads the CARINO_KEYSTORE_FILE,
# CARINO_KEYSTORE_PASSWORD, CARINO_KEY_PASSWORD and CARINO_KEY_ALIAS
# variables this script exports. Without them, release builds use the
# debug key.
#
# Usage: ./build_signed.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPO/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env at $ENV_FILE. Copy .env.example to .env and fill it in." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${CARINO_KEYSTORE_BASE64:?Missing CARINO_KEYSTORE_BASE64 in .env}"
: "${CARINO_KEYSTORE_PASSWORD:?Missing CARINO_KEYSTORE_PASSWORD in .env}"
CARINO_KEY_PASSWORD="${CARINO_KEY_PASSWORD:-$CARINO_KEYSTORE_PASSWORD}"
CARINO_KEY_ALIAS="${CARINO_KEY_ALIAS:-upload}"

TMP_KEYSTORE="$(mktemp -t carino-release-XXXXXX.jks)"
trap 'rm -f "$TMP_KEYSTORE"' EXIT
printf '%s' "$CARINO_KEYSTORE_BASE64" | base64 -d > "$TMP_KEYSTORE"

export CARINO_KEYSTORE_FILE="$TMP_KEYSTORE"
export CARINO_KEYSTORE_PASSWORD CARINO_KEY_PASSWORD CARINO_KEY_ALIAS

echo "Building signed release APKs (alias: $CARINO_KEY_ALIAS)"
( cd "$REPO" && flutter build apk --release --split-per-abi )

echo "Done: build/app/outputs/flutter-apk/app-*-release.apk"
