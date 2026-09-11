#Requires -Version 5.1
<#
    zterm one-line installer for Windows.

        irm https://zestful.dev/zterm/install.ps1 | iex

    Installs zterm ON ITS OWN — the GPU terminal without the rest of Zestful.
    zterm also ships inside Zestful; if you have Zestful installed you already
    have it, at a different path and with its own entry on PATH.

    Downloads ZtermSetup.msi from the public releases repo and installs it,
    elevating through a UAC prompt. Re-running upgrades in place.

    Beta channel:
        $env:ZTERM_VERSION = 'beta'; irm https://zestful.dev/zterm/install.ps1 | iex
    Pin a version:
        $env:ZTERM_VERSION = '0.2.0'; irm https://zestful.dev/zterm/install.ps1 | iex

    (Running the file directly, you can pass -Beta instead of the env var.)

    NOTE: the MSI is not Authenticode-signed yet, so this script does not verify a
    signature. Signature verification will be added once signing is in place.
#>
[CmdletBinding()]
param([switch]$Beta)

$ErrorActionPreference = 'Stop'

# ── Configuration ─────────────────────────────────────────────────────────────
$Repo        = 'zestfuldevelopment/zestful-terminal-downloads'
$MsiName     = 'ZtermSetup.msi'
$Site        = 'https://zestful.dev/zterm'
$ReleasesUrl = "https://github.com/$Repo/releases"

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "==> $m" -ForegroundColor Green }
function Fail($m) { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

# ── 0b. Not from inside a zterm pane ──────────────────────────────────────────
# The MSI stops zterm before replacing files, and this script would be running
# in one of its panes: the install would finish (msiexec is elevated through
# the AppInfo service and outlives us) but this script would die at the
# Start-Process below, mid-run, and the window with it. The MSI's own launch
# condition catches an interactive install; it cannot catch this one, because
# /passive skips the UI sequence where that condition is evaluated. Every zterm
# pane carries ZESTFUL_TERM_PANE_ID, so the refusal is one test, here, before
# anything is downloaded. (Refusing rather than detaching: the steps after the
# install are the script's whole reason to exist.)
if ($env:ZESTFUL_TERM_PANE_ID) {
    Fail "this is running inside a zterm pane, and installing zterm stops zterm -- which would end this script mid-install. Run ``zterm update`` instead, which starts the installer outside zterm; or run this from a terminal that is not zterm (Windows Terminal, PowerShell)."
}

# ── 1. Resolve version / channel (env var or -Beta; beta wins) ────────────────
$version = if ($env:ZTERM_VERSION) { $env:ZTERM_VERSION } else { 'latest' }
if ($Beta -or $version -eq 'beta') { $version = 'beta' }

switch ($version) {
    'beta' {
        # Rolling prerelease: the "beta" tag's assets are replaced by CI on every
        # beta publish, so this URL always serves the newest beta build.
        $url = "$ReleasesUrl/download/beta/$MsiName"
        Info 'Installing the latest zterm beta (Windows).'
    }
    'latest' {
        $url = "$ReleasesUrl/latest/download/$MsiName"
        Info 'Installing the latest zterm release (Windows).'
    }
    default {
        $tag = 'v' + ($version -replace '^v', '')   # accept "3.2.0" or "v3.2.0"
        $url = "$ReleasesUrl/download/$tag/$MsiName"
        Info "Installing zterm $tag (Windows)."
    }
}

# ── 2. Download ───────────────────────────────────────────────────────────────
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('zestful-install-' + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmp | Out-Null
$msi = Join-Path $tmp $MsiName

Info "Downloading $MsiName ..."
try {
    # TLS 1.2 for older Windows PowerShell defaults; IWR follows GitHub's redirect.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
} catch {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if ($version -eq 'beta') {
        Fail "Beta download failed. The beta channel may have no published build right now — check $ReleasesUrl, or install the stable release by clearing `$env:ZTERM_VERSION."
    }
    Fail "Download failed. Check your connection, or grab the .msi manually from $ReleasesUrl"
}
if (-not (Test-Path $msi) -or (Get-Item $msi).Length -eq 0) {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Fail "Downloaded file is empty. Try again, or see $ReleasesUrl."
}

# ── 3. Verify ─────────────────────────────────────────────────────────────────
# The Windows .msi is not Authenticode-signed yet, so there's no signature to
# check. When signing lands, verify here with Get-AuthenticodeSignature and
# require Status -eq 'Valid' + the expected subject before installing.
Write-Host 'warning: the Windows .msi is not signed yet — installing without signature verification.' -ForegroundColor Yellow

# ── 4. Install (elevates via UAC) ─────────────────────────────────────────────
Info 'Installing (a User Account Control prompt will appear) ...'
$log = Join-Path $tmp 'install.log'
$args = @('/i', "`"$msi`"", '/passive', '/norestart', '/l*v', "`"$log`"")
$proc = Start-Process 'msiexec.exe' -ArgumentList $args -Verb RunAs -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Fail "msiexec failed (exit code $($proc.ExitCode)). Install log: $log"
}
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# ── 5. Done ───────────────────────────────────────────────────────────────────
Ok 'zterm installed.'
Write-Host '    The desktop app and background daemon are set up.' -ForegroundColor DarkGray
Write-Host '    Run: zterm   To uninstall: Settings -> Apps -> Installed apps -> zterm.' -ForegroundColor DarkGray
