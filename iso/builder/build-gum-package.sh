#!/bin/bash
#
# Rebuild gum with the current Arch Go toolchain before the ISO Trivy gate.
# The Arch gum 0.17.0-1 package was built with Go 1.25.1, which currently
# trips CVE-2025-68121 in the Go stdlib embedded in /usr/bin/gum.

set -euo pipefail

if (($# != 1)); then
  echo "Usage: $0 <output_dir>" >&2
  exit 2
fi

output_dir="$1"
gum_version=0.17.0
gum_pkgrel=1.1
work_dir="$(mktemp -d)"
src_dir="$work_dir/gum"
pkgbuild_dir="$work_dir/pkgbuild"

trap 'rm -rf "$work_dir"' EXIT

id -u builder >/dev/null 2>&1 || useradd -m builder
mkdir -p "$output_dir" "$pkgbuild_dir"
chown builder:builder "$work_dir" "$output_dir"

sudo -u builder git -c http.version=HTTP/1.1 clone \
  --depth=1 \
  --branch "v$gum_version" \
  https://github.com/charmbracelet/gum.git \
  "$src_dir"

commit_sha="$(sudo -u builder git -C "$src_dir" rev-parse HEAD)"

cat > "$pkgbuild_dir/PKGBUILD" <<PKGBUILD
pkgname=gum
pkgver=$gum_version
pkgrel=$gum_pkgrel
pkgdesc='A tool for glamorous shell scripts'
arch=('x86_64')
url='https://github.com/charmbracelet/gum'
license=('MIT')
depends=('glibc')
makedepends=('go' 'git')
options=('!debug')
_src_repo='$src_dir'
_commit_sha='$commit_sha'

build() {
  cd "\$_src_repo"
  export CGO_ENABLED=0
  export GOTOOLCHAIN=local
  go build \
    -trimpath \
    -ldflags "-s -w -X main.Version=\$pkgver -X main.CommitSHA=\$_commit_sha" \
    -o gum \
    .
}

package() {
  cd "\$_src_repo"
  install -Dm755 gum "\$pkgdir/usr/bin/gum"
  install -Dm644 LICENSE "\$pkgdir/usr/share/licenses/gum/LICENSE"
}
PKGBUILD

chown -R builder:builder "$pkgbuild_dir"

pushd "$pkgbuild_dir" >/dev/null
sudo -u builder env PKGDEST="$output_dir" makepkg \
  --clean \
  --cleanbuild \
  --force \
  --noconfirm
popd >/dev/null
