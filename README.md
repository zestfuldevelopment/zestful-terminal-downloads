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

**Linux** (Debian/Ubuntu `.deb`; a clean Ubuntu may not have curl, so use wget):

```sh
wget -qO- https://zestful.dev/zterm/install.sh | sh
```

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
| Linux | Ubuntu 24.04, Debian 13 or newer (dpkg), x86_64, X11 or Wayland |
| Windows | Windows 10 22H2 or Windows 11, x64, PowerShell 5.1 or later |

## Signing

The macOS `.pkg` is verified (Developer ID signature and Apple notarization)
before it installs, and the script refuses anything that fails those checks.
The Linux `.deb` and Windows `.msi` are not signed yet, so their installers
skip signature verification for now and say so when they run.

## Channels

| Tag | |
|---|---|
| `stable` | the current release, served as `latest` |
| `beta` | rolling, replaced in place by CI on every build |

Assets keep fixed names (`ZtermSetup.pkg`, `ZtermSetup.deb`, `ZtermSetup.msi`,
and `ZtermUninstall.pkg` for macOS) so their URLs never change. Each channel
also carries a `<platform>.version` marker recording what is currently
published there.
