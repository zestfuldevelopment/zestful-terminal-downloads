# zestful-terminal-downloads

Release artifacts and one-line installers for **zterm**, the terminal your
agents can drive. Downloads only, no source.

zterm is in private beta. The site asks for an invite code; this repo does
not, and we know that. If you found your way here and want to try it, go
ahead, and say hello on [Discord](https://discord.gg/K8USgYdR) or by email to
[support@zestful.dev](mailto:support@zestful.dev), so we know who is running it
and can tell you when something changes.

## Install

**macOS** (curl ships with macOS):

```sh
curl -fsSL https://zestful.dev/zterm/install.sh | sh
```

**Linux** (a clean Ubuntu may not have curl, so use wget):

```sh
wget -qO- https://zestful.dev/zterm/install.sh | sh
```

On Debian and Ubuntu that installs the `.deb`. Anywhere without `dpkg` (Fedora,
openSUSE, Arch, ...) it installs the AppImage instead, all in your home and with
no sudo: the file in `~/Applications`, `zterm`/`zc`/`zspawn` links in
`~/.local/bin`, and a menu entry. Add `--appimage` (`sh -s -- --appimage`) to
choose the AppImage on Debian/Ubuntu too. A zterm installed this way updates
itself with `zterm update`.

**Windows** (PowerShell):

```powershell
irm https://zestful.dev/zterm/install.ps1 | iex
```

Add `--beta` (or `$env:ZTERM_VERSION = 'beta'`) to install the newest beta build
instead of the stable release.

## Requirements

| Platform | |
|---|---|
| macOS | macOS 14 (Sonoma) or later, Apple Silicon |
| Linux `.deb` | Ubuntu 24.04, Debian 13 or newer (dpkg), x86_64, X11 or Wayland |
| Linux AppImage | any distro with glibc 2.39 or newer (Fedora 40, openSUSE Tumbleweed, Arch, ...), x86_64, X11 or Wayland; no libfuse2 needed |
| Windows | Windows 10 22H2 or Windows 11, x64, PowerShell 5.1 or later |

## Signing

The macOS `.pkg` is verified (Developer ID signature and Apple notarization)
before it installs, and the script refuses anything that fails those checks.
The Linux `.deb` and AppImage and the Windows `.msi` are not signed yet, so
their installers skip signature verification for now and say so when they run.

## Channels

| Tag | |
|---|---|
| `stable` | the current release, served as `latest` |
| `beta` | rolling, replaced in place by CI on every build |

Assets keep fixed names (`ZtermSetup.pkg`, `ZtermSetup.deb`, `ZtermSetup.msi`,
`Zterm-x86_64.AppImage`, and `ZtermUninstall.pkg` for macOS) so their URLs never
change. Each channel
also carries a `<platform>.version` marker recording what is currently
published there.
