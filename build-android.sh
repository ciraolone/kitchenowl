#!/usr/bin/env bash
# Compila l'APK Android firmato del fork di Andrea (feature 001-local-first) dentro un container Flutter + Android SDK, senza installare niente sul server. La versione di Flutter è quella del sottomodulo `flutter` (3.41.7): se il sottomodulo viene aggiornato, va aggiornata anche FLUTTER_IMAGE. La chiave di firma e le sue password stanno in ~/services/kitchenowl/firma-android (fuori dal repo, dentro il backup della home): senza quella chiave l'app installata non si può più aggiornare. Il nome di versione è quello di KitchenOwl con il suffisso "-andrea.N", dove N conta i commit del fork rispetto all'originale; il numero di build cresce con N. Le cache di Gradle e dei pacchetti Dart vivono in volumi Docker, così le compilazioni successive sono veloci. L'APK, solo per telefoni arm64 (tutti quelli recenti) per restare leggero, finisce in dist/.

set -euo pipefail

FLUTTER_IMAGE="ghcr.io/cirruslabs/flutter:3.41.7"
SIGNING_DIR="$HOME/services/kitchenowl/firma-android"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$REPO_DIR/kitchenowl"

if [ ! -f "$SIGNING_DIR/key.properties" ] || [ ! -f "$SIGNING_DIR/kitchenowl.jks" ]; then
  echo "Manca la chiave di firma in $SIGNING_DIR" >&2
  exit 1
fi

upstream_version="$(grep -E '^version:' "$APP_DIR/pubspec.yaml" | sed -E 's/version: *([^+]+)\+([0-9]+)/\1 \2/')"
read -r version_name upstream_build <<<"$upstream_version"
fork_commits="$(git -C "$REPO_DIR" rev-list --count upstream/main..HEAD)"
build_name="${version_name}-andrea.${fork_commits}"
build_number=$((upstream_build * 1000 + fork_commits))

# key.properties va letto da Gradle in android/: lo si copia solo per la durata della compilazione (è in .gitignore)
cp "$SIGNING_DIR/key.properties" "$APP_DIR/android/key.properties"
trap 'rm -f "$APP_DIR/android/key.properties"' EXIT

docker run --rm \
  -v "$APP_DIR:/app" \
  -v "$SIGNING_DIR:/firma:ro" \
  -v kitchenowl-gradle-cache:/root/.gradle \
  -v kitchenowl-pub-cache:/root/.pub-cache \
  -w /app \
  "$FLUTTER_IMAGE" \
  sh -c "flutter pub get && flutter build apk --release --target-platform android-arm64 --build-name=$build_name --build-number=$build_number; status=\$?; chown -R $(id -u):$(id -g) /app/build /app/.dart_tool; exit \$status"

mkdir -p "$REPO_DIR/dist"
apk_path="$REPO_DIR/dist/kitchenowl-$build_name.apk"
cp "$APP_DIR/build/app/outputs/flutter-apk/app-release.apk" "$apk_path"
echo "APK pronto: $apk_path"
