#!/bin/sh
# zterm one-line installer for macOS and Linux.
#
#   curl -fsSL https://zestful.dev/zterm/install.sh | sh
#
# Installs zterm ON ITS OWN — the GPU terminal without the rest of Zestful.
# zterm also ships inside Zestful; if you have Zestful installed you already
# have it, and on Debian/Ubuntu the two packages conflict deliberately.
#
# Downloads the current installer from the public releases repo — the notarized
# ZtermSetup.pkg on macOS, or ZtermSetup.deb on Debian/Ubuntu — then installs
# it. Re-running upgrades in place. Pin a version with:
#
#   ZTERM_VERSION=0.2.0 curl -fsSL https://zestful.dev/zterm/install.sh | sh
#
# Install the latest beta build instead of the stable release:
#
#   curl -fsSL https://zestful.dev/zterm/install.sh | sh -s -- --beta
#
# (ZTERM_VERSION=beta works too; the flag wins if both are given.)
# On macOS the script refuses to install anything that fails Developer ID +
# notarization checks. Windows: use install.ps1.

set -eu

# ── 0. Arguments ──────────────────────────────────────────────────────────────
channel=""
for arg in "$@"; do
    case "$arg" in
        --beta) channel="beta" ;;
        *) printf 'error: unknown option: %s (supported: --beta)\n' "$arg" >&2; exit 1 ;;
    esac
done

# ── Configuration ─────────────────────────────────────────────────────────────
REPO="zestfuldevelopment/zestful-terminal-downloads"
# 11, not Zestful's 14: zterm's bundle declares LSMinimumSystemVersion 11.0 —
# the first macOS with Apple Silicon, which is the only architecture it ships.
MIN_MACOS_MAJOR=11
SITE="https://zestful.dev/zterm"
RELEASES_URL="https://github.com/$REPO/releases"

# ── Output helpers (color only on a terminal) ─────────────────────────────────
if [ -t 1 ]; then
    BOLD=$(printf '\033[1m'); DIM=$(printf '\033[2m')
    RED=$(printf '\033[31m'); GRN=$(printf '\033[32m'); RST=$(printf '\033[0m')
else
    BOLD=''; DIM=''; RED=''; GRN=''; RST=''
fi
info() { printf '%s==>%s %s\n' "$BOLD" "$RST" "$1"; }
ok()   { printf '%s==>%s %s\n' "$GRN" "$RST" "$1"; }
warn() { printf '%swarning:%s %s\n' "$RED" "$RST" "$1" >&2; }
fail() { printf '%serror:%s %s\n' "$RED" "$RST" "$1" >&2; exit 1; }

# Download URL -> file, using whichever fetcher is present. A clean Ubuntu ships
# neither curl nor wget reliably, so we don't hard-depend on curl (macOS always
# has it; Linux commonly has wget). Both are forced to HTTPS.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL --proto '=https' --tlsv1.2 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --https-only -O "$2" "$1"
    else
        fail "Need curl or wget to download, but neither is installed.
       Install one (e.g. 'sudo apt-get install -y wget') and re-run."
    fi
}

# ── 1. Platform detection + guard ─────────────────────────────────────────────
case "$(uname -s)" in
    Darwin)
        platform="macos"; PKG_NAME="ZtermSetup.pkg"
        os_major=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)
        case "$os_major" in
            ''|*[!0-9]*) fail "Could not determine macOS version." ;;
        esac
        [ "$os_major" -ge "$MIN_MACOS_MAJOR" ] || \
            fail "zterm needs macOS $MIN_MACOS_MAJOR (Big Sur) or later. You have $(sw_vers -productVersion)."
        ;;
    Linux)
        platform="linux"; PKG_NAME="ZtermSetup.deb"
        command -v dpkg >/dev/null 2>&1 || \
            fail "This installer is a Debian/Ubuntu .deb, but dpkg wasn't found.
       For other distros, grab the build from $RELEASES_URL."
        ;;
    *)
        fail "This script installs zterm on macOS and Linux.
       On Windows, run install.ps1 — see $SITE." ;;
esac

# ── 2. Resolve version ────────────────────────────────────────────────────────
version="${ZTERM_VERSION:-latest}"
[ "$channel" = "beta" ] && version="beta"
if [ "$version" = "beta" ]; then
    # Rolling prerelease: the "beta" tag's assets are replaced by CI on every
    # beta publish, so this URL always serves the newest beta build.
    url="$RELEASES_URL/download/beta/$PKG_NAME"
    info "Installing the latest zterm beta ($platform)."
elif [ "$version" = "latest" ]; then
    url="$RELEASES_URL/latest/download/$PKG_NAME"
    info "Installing the latest zterm release ($platform)."
else
    # Accept "3.2.0" or "v3.2.0".
    tag="v${version#v}"
    url="$RELEASES_URL/download/$tag/$PKG_NAME"
    info "Installing zterm $tag ($platform)."
fi

# ── 3. Download ───────────────────────────────────────────────────────────────
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zterm-install.XXXXXX") || fail "Could not create a temp directory."
trap 'rm -rf "$tmp"' EXIT INT TERM
pkg="$tmp/$PKG_NAME"

info "Downloading $PKG_NAME ..."
if ! download "$url" "$pkg"; then
    if [ "$version" = "beta" ]; then
        fail "Beta download failed. The beta channel may not have a published
       build right now — check $RELEASES_URL, or install the stable
       release by re-running without --beta."
    fi
    fail "Download failed. Check your connection, or grab the installer manually from:
       $RELEASES_URL"
fi
[ -s "$pkg" ] || fail "Downloaded file is empty. Try again, or see $RELEASES_URL."

# ── 4. Verify ─────────────────────────────────────────────────────────────────
if [ "$platform" = "macos" ]; then
    info "Verifying signature and notarization ..."
    if ! sig=$(pkgutil --check-signature "$pkg" 2>&1); then
        warn "$sig"
        fail "Package signature could not be read. Aborting — not installing an unverified package."
    fi
    case "$sig" in
        *"Developer ID Installer"*) : ;;
        *) warn "$sig"
           fail "Package is not signed with a Developer ID Installer certificate. Aborting." ;;
    esac
    if ! spctl --assess --type install "$pkg" >/dev/null 2>&1; then
        fail "Package is not notarized / not accepted by Gatekeeper. Aborting.
       Download manually and inspect: $RELEASES_URL"
    fi
    ok "Verified: Developer ID-signed and notarized."
else
    # The Linux .deb is not signed yet, so there's no signature to verify here.
    # (Signing applies to an apt repo's Release file, which we don't publish yet.)
    warn "The Linux .deb is not signed yet — installing without signature verification."
fi

# ── 5. Install (needs root) ───────────────────────────────────────────────────
# Our own stdin is the curl pipe, so sudo reads the password from /dev/tty.
if [ "$(id -u)" -eq 0 ]; then
    ESC="root"
elif [ -r /dev/tty ]; then
    ESC="sudo"
else
    warn "No terminal available for the administrator password."
    if [ "$platform" = "macos" ]; then
        manual="sudo installer -pkg \"$pkg\" -target /"
    else
        manual="sudo dpkg -i \"$pkg\" || sudo apt-get -f install -y"
    fi
    printf '       Finish the install with:\n\n         %s\n\n' "$manual"
    trap - EXIT  # keep the downloaded installer around for the manual step
    fail "Cannot prompt for password; installer left at $pkg"
fi

priv() {
    if [ "$ESC" = "root" ]; then "$@"; else sudo -p "Password (to install zterm): " "$@"; fi
}

if [ "$ESC" = "sudo" ]; then
    info "Installing (you'll be asked for your password) ..."
else
    info "Installing ..."
fi

if [ "$platform" = "macos" ]; then
    priv installer -pkg "$pkg" -target / || fail "installer failed."
else
    # dpkg installs the package; apt-get -f resolves any missing dependencies.
    priv sh -c 'dpkg -i "$1" || apt-get -f install -y' _ "$pkg" || fail "dpkg install failed."
fi

# ── 6. Done ───────────────────────────────────────────────────────────────────
ok "zterm installed."
if [ "$platform" = "macos" ]; then
    printf '%s    Open zterm from Applications, or run: zterm%s\n' "$DIM" "$RST"
    printf '%s    To uninstall: run the ZtermUninstall.pkg from %s%s\n' "$DIM" "$RELEASES_URL" "$RST"
else
    printf '%s    Run: zterm   To uninstall:  sudo apt-get remove zterm%s\n' "$DIM" "$RST"
fi
