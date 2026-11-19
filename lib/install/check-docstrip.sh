#!/usr/bin/env bash
set -euo pipefail

source_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

cp -R "$source_root/build.sh" "$source_root/VERSION" "$source_root/src" "$scratch/"
mkdir -p "$scratch/lib/ruby"
cp -R "$source_root/lib/install" "$scratch/lib/"
cp "$source_root/lib/ruby/Gemfile" "$source_root"/lib/ruby/*.rb "$scratch/lib/ruby/"

(
    cd "$scratch"
    touch source.sh
    export BUNDLE_PATH="$PWD/gems"
    (cd lib/ruby && bundle install)
    ./build.sh

    cd build
    # The class digest records the installed class with the startup guard.
    echo '29ac17c9be114cec94af6d661d01eae0e4ea732ab8c1a106f36b909dbf17cfc2  cocotex.cls' | sha256sum --check
)
