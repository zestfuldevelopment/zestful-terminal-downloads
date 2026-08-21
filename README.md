# zestful-terminal-downloads

Public release artifacts + one-line installers for **zterm**, the GPU terminal
from [Zestful](https://zestful.dev). Downloads only — no source.

zterm also ships inside Zestful itself. This channel is for running the terminal
on its own, without the rest of the product.

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

The macOS `.pkg` is verified (Developer ID signature + Apple notarization) before
it installs, and the script refuses anything that fails those checks. The Linux
`.deb` and Windows `.msi` are **not signed yet**, so their installers skip
signature verification for now and say so when they run.

Add `--beta` (or `$env:ZTERM_VERSION = 'beta'`) to install the newest beta build
instead of the stable release.

## Channels

| Tag | |
|---|---|
| `stable` | the current release, served as `latest` |
| `beta` | rolling — replaced in place by CI on every build |

Assets keep fixed names (`ZtermSetup.deb`, and `ZtermSetup.pkg` / `ZtermSetup.msi`
when those arrive) so their URLs never change. Each channel also carries a
`<platform>.version` marker recording what is currently published there.

## Note on installing alongside Zestful

The Zestful package already contains this same binary. On Linux the two declare a
conflict and dpkg will refuse to install both — pick one.

## Versioning

zterm's version line is its own and does not track Zestful's. The point of
shipping the terminal separately is that it can move at its own pace.
