# zestful-terminal-downloads

Public release artifacts + one-line installers for **zterm**, the GPU terminal
from [Zestful](https://zestful.dev). Downloads only — no source.

zterm also ships inside Zestful itself. This channel is for running the terminal
on its own, without the rest of the product.

## Install

**Linux** (Debian/Ubuntu `.deb`):

```sh
wget -qO- https://raw.githubusercontent.com/zestfuldevelopment/zestful-terminal-downloads/main/install.sh | sh
```

macOS and Windows follow once their installers land.

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
