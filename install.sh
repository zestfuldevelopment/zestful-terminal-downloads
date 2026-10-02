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
# Progress is shown on BOTH paths. curl's default meter and wget's bar go to
# stderr, which is still the terminal when the script arrives through `| sh`,
# so a 10 MB download no longer looks like a hang. wget keeps -q to silence its
# connection chatter, with --show-progress putting the bar back.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL --proto '=https' --tlsv1.2 --progress-bar -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --show-progress --https-only -O "$2" "$1"
    else
        fail "Need curl or wget to download, but neither is installed.
       Install one (e.g. 'sudo apt-get install -y wget') and re-run."
    fi
}

# The HTTP status for a URL, without fetching the body -- empty when the server
# could not be reached at all. This is asked BEFORE the download so a missing
# asset and a dead network can be told apart and reported differently.
#
# Not inferred from the fetcher's exit code, which was the first attempt and was
# wrong: a GitHub release asset 404s only after a redirect to its storage host,
# and curl surfaces that as exit 56 (mid-transfer) rather than 22 (HTTP error).
# The code to expect therefore varies with where in the redirect chain the
# refusal lands, which is not a thing to encode. The server's own answer is.
head_status() {
    if command -v curl >/dev/null 2>&1; then
        curl -sIL --proto '=https' --tlsv1.2 --max-time 20 \
             -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true
    elif command -v wget >/dev/null 2>&1; then
        # wget prints the status lines to stderr; the LAST one is the end of
        # the redirect chain.
        # wget -S prints each response's status line to stderr, indented; the
        # LAST one is the end of the redirect chain. Matched by finding the
        # HTTP/ token anywhere on the line rather than by its indentation,
        # which has not been identical across wget versions.
        wget -q --https-only --timeout=20 --spider -S "$1" 2>&1 \
            | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^HTTP\//) code = $(i + 1) }
                   END { print code }' || true
    fi
}

# A small text asset to stdout, quietly. Empty on any failure -- every caller
# treats the version as a nicety and carries on without it, because not being
# able to NAME the build is no reason to refuse to install it.
fetch_quiet() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=https' --tlsv1.2 --max-time 15 "$1" 2>/dev/null || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q --https-only --timeout=15 -O - "$1" 2>/dev/null || true
    fi
}

# Bytes -> something a person reads. Integer MB via awk, which both platforms
# have; `wc -c` rather than stat, whose flags differ between macOS and Linux.
human_size() {
    awk -v b="$1" 'BEGIN { if (b >= 1048576) printf "%.1f MB", b/1048576;
                           else if (b >= 1024) printf "%.0f KB", b/1024;
                           else printf "%d bytes", b }'
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
        # Not from inside a zterm pane. The package's preinstall stops zterm
        # before replacing zterm.app -- so this script, running in one of its
        # panes, would die mid-install with the window. The pkg cannot refuse
        # this itself (preinstall runs under installd, and sudo resets the
        # environment); this script runs in the pane, before sudo, and can.
        # Every zterm pane carries ZESTFUL_TERM_PANE_ID. Linux is not guarded:
        # the .deb's prerm sees a hosting zterm above it and leaves it alone.
        [ -z "${ZESTFUL_TERM_PANE_ID:-}" ] || \
            fail "this is running inside a zterm pane, and installing zterm stops zterm -- which ends this
       script mid-install, and the window with it. Run 'zterm update' instead, which starts the
       installer outside zterm; or run this from a terminal that is not zterm (Terminal.app, iTerm)."
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
# Every channel publishes a `<platform>.version` asset beside the package, so
# the build can be NAMED before it is fetched rather than described as "the
# latest" and never identified. Best effort: if the file is missing or the
# network is slow, the channel is still announced and the install proceeds.
case "$platform" in
    macos) VERSION_ASSET="mac.version" ;;
    *)     VERSION_ASSET="linux.version" ;;
esac

if [ "$version" = "beta" ]; then
    # Rolling prerelease: the "beta" tag's assets are replaced by CI on every
    # beta publish, so this URL always serves the newest beta build.
    url="$RELEASES_URL/download/beta/$PKG_NAME"
    channel_desc="beta channel"
    found=$(fetch_quiet "$RELEASES_URL/download/beta/$VERSION_ASSET")
elif [ "$version" = "latest" ]; then
    url="$RELEASES_URL/latest/download/$PKG_NAME"
    channel_desc="stable channel"
    found=$(fetch_quiet "$RELEASES_URL/latest/download/$VERSION_ASSET")
else
    # Accept "3.2.0" or "v3.2.0".
    tag="v${version#v}"
    url="$RELEASES_URL/download/$tag/$PKG_NAME"
    channel_desc="release $tag"
    found=$(fetch_quiet "$RELEASES_URL/download/$tag/$VERSION_ASSET")
fi
found=$(printf '%s' "$found" | tr -d '\r\n ')

if [ -n "$found" ]; then
    info "Installing zterm $found — $channel_desc, $platform."
else
    info "Installing zterm from the $channel_desc ($platform)."
fi
printf '%s    from %s%s\n' "$DIM" "$url" "$RST"

# ── 3. Download ───────────────────────────────────────────────────────────────
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zterm-install.XXXXXX") || fail "Could not create a temp directory."
trap 'rm -rf "$tmp"' EXIT INT TERM
pkg="$tmp/$PKG_NAME"

# Ask before fetching, so the reason for a failure is the server's and not a
# guess. Blaming the network for a 404 is what sent people to look at their
# wifi over a missing asset.
status=$(head_status "$url")
case "$status" in
    200|"")
        # 200, or a server that would not answer a HEAD -- some proxies will
        # not. An empty answer is not treated as failure: the download below
        # is the real attempt, and refusing to try on a HEAD that did not
        # work would be worse than trying and reporting what happened.
        : ;;
    404)
        if [ "$version" = "beta" ]; then
            fail "The beta channel has no $PKG_NAME right now (the server returned 404).
       Check $RELEASES_URL, or install the stable release by
       re-running without --beta."
        fi
        # GitHub answers 404, not 403, for a private repository's assets when
        # the client is anonymous -- so "missing" and "not public" are the same
        # status here and the message has to name both.
        fail "There is no $PKG_NAME at that URL — the server returned 404, so this is
       not a connection problem. Either this release has no build for $platform,
       the version does not exist, or the release is not public. What is
       published:
       $RELEASES_URL"
        ;;
    401|403)
        fail "The download server refused access ($status). The release may be private
       or still publishing. If this persists, report it — a public installer
       should never need credentials.
       $RELEASES_URL"
        ;;
    *)
        warn "the server answered $status for the package URL; trying the download anyway."
        ;;
esac

info "Downloading $PKG_NAME ..."
if ! download "$url" "$pkg"; then
    fail "The download did not complete (server said ${status:-?}).
       Check your connection or proxy and re-run, or fetch it by hand from:
       $RELEASES_URL"
fi
[ -s "$pkg" ] || fail "Downloaded file is empty. Try again, or see $RELEASES_URL."
ok "Downloaded $(human_size "$(wc -c < "$pkg" | tr -d ' ')")."

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
# Asked of the thing that was just installed, not of the thing that was
# downloaded. A package can install and still leave an older binary first on
# PATH -- a stale /usr/local/bin shim, a Homebrew copy -- and "installed." with
# no version is exactly the report that hides it.
installed=$(command -v zterm >/dev/null 2>&1 && zterm --version 2>/dev/null | head -1 | tr -d '\r')
if [ -n "$installed" ]; then
    ok "Installed: $installed"
    # Only when both are known AND disagree. A version we could not fetch is
    # not evidence of a mismatch.
    case "$installed" in
        *"$found"*) : ;;
        *) [ -z "$found" ] || warn "expected $found, but 'zterm --version' reports: $installed
         another zterm may be earlier on your PATH: $(command -v zterm 2>/dev/null)" ;;
    esac
else
    ok "zterm installed."
fi

if [ "$platform" = "macos" ]; then
    printf '%s    /Applications/zterm.app   and the shim  /usr/local/bin/zterm%s\n' "$DIM" "$RST"
    printf '%s    Open zterm from Applications, or run: zterm%s\n' "$DIM" "$RST"
    printf '%s    To uninstall: run the ZtermUninstall.pkg from %s%s\n' "$DIM" "$RELEASES_URL" "$RST"
else
    printf '%s    Run: zterm   To uninstall:  sudo apt-get remove zterm%s\n' "$DIM" "$RST"
fi
