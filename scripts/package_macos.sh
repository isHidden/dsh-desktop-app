#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  aarch64) macos_arch=arm64 ;;
  x86_64) macos_arch=x86_64 ;;
  *) echo 'Usage: bash scripts/package_macos.sh aarch64|x86_64' >&2; exit 1 ;;
esac

# Deno 2.9.7 only signs the assembled app on macOS. Cross-builds retain
# linker signatures but do not seal the app's Info.plist, resources or helpers.
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'macOS distribution packaging requires macOS for codesign. Use the macOS CI artifacts, or build on a Mac.' >&2
  echo "For an unsigned development cross-build, use: deno task build:macos:$1" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
deno task "build:macos:$1"

archive="$PWD/dist/macos/DSH-Desktop-macos-$1.tar.gz"
tar -czf "$archive" -C "dist/macos/$1" DSH-Desktop.app

# Verify the bytes users unpack, including tar's preservation of framework
# symlinks and executable permissions. Never upload an unverified archive.
verification_dir=$(mktemp -d)
trap 'rm -rf "$verification_dir"' EXIT
tar -xzf "$archive" -C "$verification_dir"
app="$verification_dir/DSH-Desktop.app"
executable=$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")
test -x "$app/Contents/MacOS/$executable"
test -s "$app/Contents/_CodeSignature/CodeResources"
codesign --verify --deep --strict --verbose=4 "$app"

while IFS= read -r -d '' bundle_file; do
  if [[ "$(file -b "$bundle_file")" == *Mach-O* ]]; then
    lipo -verify_arch "$macos_arch" "$bundle_file"
    codesign --verify --strict --verbose=2 "$bundle_file"
  fi
done < <(find "$app" -type f -print0)

while IFS= read -r -d '' bundle_link; do
  if [[ ! -e "$bundle_link" ]]; then
    echo "Broken bundle symlink: $bundle_link" >&2
    exit 1
  fi
done < <(find "$app" -type l -print0)

echo "Verified macOS $macos_arch distribution: $archive"
