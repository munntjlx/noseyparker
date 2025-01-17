#!/bin/zsh

set -eu

fatal() {
    echo >&2 "error: $@"
    exit 1
}

banner() {
    echo "################################################################################"
    echo "# $@"
    echo "################################################################################"
}

ensure_has_program() {
    prog="$1"
    command -v "$prog" >/dev/null || fatal "missing program $prog"
}


# The directory containing this script
HERE=${0:a:h}


################################################################################
# Determine build configuration
################################################################################
# Figure out which platform we are creating a release for
case $(uname) in
    Darwin*)
        PLATFORM="macos"
        CARGO_FEATURES="release"
    ;;

    Linux*)
        PLATFORM="linux"
        CARGO_FEATURES="release"
    ;;

    *)
        fatal "unknown platform"
    ;;
esac

################################################################################
# Environment sanity checking
################################################################################
if [[ $PLATFORM == 'linux' ]]; then
    ensure_has_program ldd
    ensure_has_program readelf
elif [[ $PLATFORM == 'macos' ]]; then
else
    fatal "unknown platform $PLATFORM"
fi
ensure_has_program sha256sum

banner "Build configuration"
echo "uname: $(uname)"
echo "uname -p: $(uname -p)"
echo "arch: $(arch)"
echo "PLATFORM: $PLATFORM"
echo "CARGO_FEATURES: $CARGO_FEATURES"


################################################################################
# Create release
################################################################################
# Go to the repository root
cd "$HERE/.."

# Where should the release output get put?
RELEASE_DIR="release"

# Where does `cargo` build stuff?
CARGO_BUILD_DIR="target/release"

mkdir "$RELEASE_DIR" || fatal "could not create release directory"
mkdir "$RELEASE_DIR"/{bin,share,share/completions} || fatal "could not create release directory tree"

# Build release version of noseyparker into the release dir
banner "Building release with Cargo"
cargo build --locked --profile release --features "$CARGO_FEATURES" || fatal "failed to build noseyparker"

banner "Assembling release dir"
# Copy binary into release dir
NP="$PWD/$RELEASE_DIR/bin/noseyparker"
cp -p "$CARGO_BUILD_DIR/noseyparker-cli" "$NP"
strip --strip-all $NP
################################################################################
# Shell completion generation
################################################################################
for SHELL in bash zsh fish powershell elvish; do
    "$NP" shell-completions --shell zsh >"$RELEASE_DIR/share/completions/noseyparker.$SHELL"
done

################################################################################
# Sanity checking
################################################################################
banner "Release file sha256 digests"
find "$RELEASE_DIR" -type f -print0 | xargs -0 sha256sum | sort -k2

banner "Release disk use"
find "$RELEASE_DIR" -type f -print0 | xargs -0 du -shc | sort -h -k1,1

if [[ $PLATFORM == 'linux' ]]; then
    banner "ldd output for noseyparker"
    ldd "$NP"

    banner "readelf -d output for noseyparker"
    readelf -d "$NP"

elif [[ $PLATFORM == 'macos' ]]; then
    banner "otool -L output for noseyparker"
    otool -L "$NP"

    banner "otool -l output for noseyparker"
    otool -l "$NP"

else
    fatal "unknown platform $PLATFORM"
fi

banner "noseyparker --version"
"$NP" --version

banner "Complete!"
