#Requires -Version 5.1
<#
    ucInstaller packaging script (T050 / design.md 4.12.3).

    Assembles dist/ucInstaller-win-x64/ so the installer can run on a machine
    that has neither the Cangjie SDK nor the repo:

        ucInstaller.exe          <- renamed from target/release/bin/main.exe
        *.dll                    <- Cangjie std DLLs (SDK) + stdx DLLs (libs)
        libcrypto-3-x64.dll      <- OpenSSL 3.x, RENAMED to the exact names
        libssl-3-x64.dll            the stdx loader hardcodes (AC-159 / R-15)
        assets/install.{html,js,css}
        media/                   <- offline release tarball (optional)
        .env.example
        start-installer.bat

    Why every DLL sits next to the exe: there is no PATH dependency allowed
    (design.md 4.12.3). The stdx OpenSSL FFI loader looks up
    libcrypto-3-x64.dll / libssl-3-x64.dll by literal filename, so a source
    file named libcrypto-3.dll (or 4.x) MUST be renamed, never just copied.

    Usage:
        powershell -NoProfile -ExecutionPolicy Bypass -File package.ps1
        powershell ... -File package.ps1 -OutDir D:\dist\x -Media <tar.gz>
        powershell ... -File package.ps1 -SkipSmoke

    Exit codes: 0 = packaged and gated OK, 1 = gate failed (dist is unusable).
#>

[CmdletBinding()]
param(
    [string] $OutDir = "",
    [string] $Media = "",
    [switch] $SkipMedia,
    [switch] $SkipSmoke,
    [switch] $KeepOut
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- paths ----

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RuntimeRoot = Split-Path -Parent $ScriptDir
$RepoRoot    = Split-Path -Parent $RuntimeRoot          # apps/
$BinDir      = Join-Path $ScriptDir 'target\release\bin'
$StdxDir     = Join-Path $RuntimeRoot 'libs\cangjie-stdx-windows-x64-1.1.3.1\windows_x86_64_cjnative\dynamic\stdx'
$AssetsDir   = Join-Path $ScriptDir 'assets'
$EnvExample  = Join-Path $RuntimeRoot '.env.example'
$BatSrc      = Join-Path $RepoRoot 'web-admin\start-installer.bat'

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $RuntimeRoot 'dist\ucInstaller-win-x64'
}
$OutAssets = Join-Path $OutDir 'assets'
$OutMedia  = Join-Path $OutDir 'media'

$gate = New-Object System.Collections.ArrayList

function Say([string] $msg) { Write-Host $msg }
function Step([string] $msg) { Write-Host "[STEP] $msg" -ForegroundColor Cyan }
function Ok([string] $msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn([string] $msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Fail([string] $msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    [void] $gate.Add($msg)
}

function CopyDlls([string] $srcDir, [string] $dstDir, [string] $label) {
    if (-not (Test-Path $srcDir)) {
        Fail "$label DLL source missing: $srcDir"
        return 0
    }
    # .dll only - *.dll.a are import libraries, useless at runtime (~30 MB saved)
    $files = Get-ChildItem -Path $srcDir -Filter '*.dll' -File
    $n = 0
    foreach ($f in $files) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dstDir $f.Name) -Force
        $n++
    }
    Ok "Copied $n $label DLL(s)"
    return $n
}

function FindOpenSslDll([string] $leafPattern) {
    $candidates = New-Object System.Collections.ArrayList

    # 1. already-built runtime output (self-contained, preferred)
    [void] $candidates.Add((Join-Path $RuntimeRoot 'target\release\bin'))
    # 2. the dist we are rebuilding (idempotent rerun)
    [void] $candidates.Add($OutDir)
    # 3. standard OpenSSL installs
    [void] $candidates.Add('C:\Program Files\OpenSSL-Win64\bin')
    [void] $candidates.Add('C:\Program Files\OpenSSL\bin')
    [void] $candidates.Add('C:\Program Files (x86)\OpenSSL-Win64\bin')
    # 4. whatever openssl on PATH resolves to
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if ($null -ne $openssl) {
        [void] $candidates.Add((Split-Path -Parent $openssl.Source))
    }

    foreach ($dir in $candidates) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        if (-not (Test-Path $dir)) { continue }
        $hit = Get-ChildItem -Path $dir -Filter $leafPattern -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($null -ne $hit) { return $hit.FullName }
    }
    return $null
}

# ------------------------------------------------------------- prepare ----

Say '========================================='
Say ' ucInstaller packaging (T050)'
Say '========================================='
Say "Runtime root : $RuntimeRoot"
Say "Output dir   : $OutDir"
Say ''

if (-not (Test-Path $BinDir)) {
    Fail "Build output missing: $BinDir  (run: cd installer && cjpm build)"
    exit 1
}

$exeSrc = Join-Path $BinDir 'main.exe'
if (-not (Test-Path $exeSrc)) {
    Fail "main.exe not found in $BinDir (cjpm output-type=executable, entry src/main.cj)"
    exit 1
}

if ((Test-Path $OutDir) -and -not $KeepOut) {
    Step "Cleaning previous output: $OutDir"
    Remove-Item -LiteralPath $OutDir -Recurse -Force
}
foreach ($d in @($OutDir, $OutAssets, $OutMedia)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# --------------------------------------------------------------- exe ------

Step 'Installing executable as ucInstaller.exe'
$exeDst = Join-Path $OutDir 'ucInstaller.exe'
Copy-Item -LiteralPath $exeSrc -Destination $exeDst -Force
if (Test-Path $exeDst) { Ok 'ucInstaller.exe' } else { Fail 'ucInstaller.exe not written' }

# ------------------------------------------------ dependency DLLs ---------
# Dependencies NOT declared output-type="static" build a DLL of their own under
# target/release/<dep>/. They are as required as the std DLLs: main.exe imports
# libblowfish.dll directly (bcrypt, T028) and exits 0xC0000135 without it.
# Verified by the smoke test below - do not drop this step.

Step 'Copying project dependency DLLs (blowfish / json4cj / zip4cj ...)'
$depCount = 0
$depRoot = Join-Path $ScriptDir 'target\release'
$depDirs = Get-ChildItem -Path $depRoot -Directory -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -ne 'bin' -and $_.Name -ne 'uc_installer' -and $_.Name -notlike '.*' }
foreach ($d in $depDirs) {
    foreach ($f in (Get-ChildItem -Path $d.FullName -Filter '*.dll' -File -ErrorAction SilentlyContinue)) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $OutDir $f.Name) -Force
        $depCount++
    }
}
if ($depCount -gt 0) { Ok "Copied $depCount dependency DLL(s)" }
else { Fail "no dependency DLLs under $depRoot\* (blowfish is expected)" }

# ------------------------------------------------------- Cangjie std DLLs --

Step 'Copying Cangjie std DLLs (--dy-std => must sit next to the exe)'
$sdkDir = $null
$sdkCandidates = New-Object System.Collections.ArrayList
if ($env:CANGJIE_HOME) { [void] $sdkCandidates.Add((Join-Path $env:CANGJIE_HOME 'runtime\lib\windows_x86_64_cjnative')) }
[void] $sdkCandidates.Add('D:\Program Files (x86)\Cangjie\runtime\lib\windows_x86_64_cjnative')
[void] $sdkCandidates.Add('C:\Program Files\Cangjie\runtime\lib\windows_x86_64_cjnative')
foreach ($c in $sdkCandidates) {
    if (Test-Path $c) { $sdkDir = $c; break }
}
if ($null -ne $sdkDir) {
    Say "  source: $sdkDir"
    CopyDlls $sdkDir $OutDir 'std'
} else {
    Fail 'Cangjie SDK runtime lib dir not found (set $env:CANGJIE_HOME)'
}

# ---------------------------------------------------------- stdx DLLs ------

Step 'Copying stdx DLLs'
CopyDlls $StdxDir $OutDir 'stdx'

# ------------------------------------------------------------ OpenSSL ------

Step 'Normalizing OpenSSL 3.x DLL filenames (stdx loader hardcodes *-x64.dll)'
foreach ($pair in @(
        @{ Src = 'libcrypto-3*.dll'; Dst = 'libcrypto-3-x64.dll' },
        @{ Src = 'libssl-3*.dll';    Dst = 'libssl-3-x64.dll' }
    )) {
    $found = FindOpenSslDll $pair.Src
    if ($null -eq $found) {
        Fail "OpenSSL DLL not found for pattern $($pair.Src) - stdx TLS FFI will fall back to the system OpenSSL and may fail on 4.x machines"
        continue
    }
    Copy-Item -LiteralPath $found -Destination (Join-Path $OutDir $pair.Dst) -Force
    Ok "$($pair.Dst) <- $found"
}

# ------------------------------------------------------------- assets ------

Step 'Copying static wizard assets'
# NOTE: bootstrap.cj resolves assetsDir = <cwd>/assets and serves /install.html
# from that directory root. design.md 4.12.3 draws assets/install/, which the
# compiled code does NOT read - follow the code, otherwise the wizard 404s.
foreach ($n in @('install.html', 'install.js', 'install.css')) {
    $src = Join-Path $AssetsDir $n
    if (Test-Path $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $OutAssets $n) -Force
        Ok $n
    } else {
        Fail "asset missing: $src"
    }
}

# ----------------------------------------------------------- media/env -----

Step 'Copying .env.example'
if (Test-Path $EnvExample) {
    Copy-Item -LiteralPath $EnvExample -Destination (Join-Path $OutDir '.env.example') -Force
    Ok '.env.example'
} else {
    Fail ".env.example missing: $EnvExample"
}

if (-not $SkipMedia) {
    Step 'Staging offline release media'
    $mediaFile = $null
    if (-not [string]::IsNullOrWhiteSpace($Media)) {
        if (Test-Path $Media) { $mediaFile = $Media }
        else { Fail "media file not found: $Media" }
    } else {
        $hits = @()
        $hits += Get-ChildItem -Path (Join-Path $RuntimeRoot 'dist') -Filter '*.tar.gz' -File -ErrorAction SilentlyContinue
        $hits += Get-ChildItem -Path $RuntimeRoot -Filter 'agentskills-runtime-win-x64*.tar.gz' -File -ErrorAction SilentlyContinue
        $hits += Get-ChildItem -Path $RuntimeRoot -Filter 'agentskills-runtime-win-x64*.zip' -File -ErrorAction SilentlyContinue
        if ($hits.Count -gt 0) { $mediaFile = $hits[0].FullName }
    }
    if ($null -ne $mediaFile) {
        Copy-Item -LiteralPath $mediaFile -Destination (Join-Path $OutMedia (Split-Path -Leaf $mediaFile)) -Force
        Ok "media/$(Split-Path -Leaf $mediaFile)"
    } else {
        # Not a failure: tracks D1/D2 fetch the tarball separately. Say it loud.
        Warn 'no release tarball found - media/ left empty'
        Say '       pass -Media <path> to bundle it (track D3 "PC, no second download")'
    }
}

# ------------------------------------------------------- launcher script ---

Step 'Copying start-installer.bat'
if (Test-Path $BatSrc) {
    Copy-Item -LiteralPath $BatSrc -Destination (Join-Path $OutDir 'start-installer.bat') -Force
    Ok 'start-installer.bat'
} else {
    Fail "start-installer.bat missing: $BatSrc"
}

# ---------------------------------------------------------------- gate -----

Step 'Post-package gate'
foreach ($n in @('ucInstaller.exe', 'libcrypto-3-x64.dll', 'libssl-3-x64.dll',
                 'libblowfish.dll', 'start-installer.bat', '.env.example')) {
    if (Test-Path (Join-Path $OutDir $n)) { Ok $n } else { Fail "missing: $n" }
}
$stdDlls  = (Get-ChildItem -Path $OutDir -Filter 'libcangjie-*.dll' -File -ErrorAction SilentlyContinue).Count
$stdxDlls = (Get-ChildItem -Path $OutDir -Filter 'libstdx*.dll' -File -ErrorAction SilentlyContinue).Count
if ($stdDlls -gt 0) { Ok "$stdDlls std DLL(s)" } else { Fail 'no libcangjie-*.dll copied' }
if ($stdxDlls -gt 0) { Ok "$stdxDlls stdx DLL(s)" } else { Fail 'no libstdx*.dll copied' }

if (-not $SkipSmoke) {
    Step 'Smoke test: ucInstaller.exe help (proves DLL resolution)'
    $prev = Get-Location
    try {
        Set-Location -LiteralPath $OutDir
        $out = & (Join-Path $OutDir 'ucInstaller.exe') help 2>&1
        $code = $LASTEXITCODE
        if ($code -eq 0) { Ok "exit 0, usage printed ($($out.Count) line(s))" }
        else { Fail "ucInstaller.exe help exited $code : $out" }
    } finally {
        Set-Location -LiteralPath $prev
    }
}

# -------------------------------------------------------------- report -----

$total = (Get-ChildItem -Path $OutDir -Recurse -File | Measure-Object -Property Length -Sum)
$sizeMb = [math]::Round(($total.Sum / 1MB), 1)
Say ''
Say '========================================='
Say " output : $OutDir"
Say " files  : $($total.Count)   size: $sizeMb MB"
Say '========================================='

if ($gate.Count -gt 0) {
    Say ''
    Say "GATE FAILED ($($gate.Count) issue(s)) - the dist is NOT usable:" -ForegroundColor Red
    foreach ($g in $gate) { Say "  - $g" -ForegroundColor Red }
    exit 1
}

Say ''
Say 'Packaged OK. Next:'
Say '  cd <dist>\ucInstaller-win-x64 && start-installer.bat'
Say '  (or: ucInstaller.exe --json check-environment)'
exit 0
