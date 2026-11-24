# Install fixed browser-only audio engine assets. Run from any directory.
# Requires Node.js/npm. Nothing is installed globally or uploaded.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root 'web/vendor/ffmpeg'
$stamp = Join-Path $target 'versions.txt'
$versions = '@ffmpeg/ffmpeg@0.12.15 + @ffmpeg/core@0.12.10'
$required = @('wrapper/index.js','wrapper/classes.js','wrapper/worker.js','core/ffmpeg-core.js','core/ffmpeg-core.wasm')
if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $versions)) {
    $missing = @($required | Where-Object { -not (Test-Path (Join-Path $target $_)) })
    if ($missing.Count -eq 0) {
        Write-Host 'HQ browser audio engine is already installed.'
        exit 0
    }
}
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw 'Node.js/npm required. Install Node.js LTS, reopen VS Code, then rerun this script.'
}
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('kontrios-wasm-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    & npm.cmd install --prefix $temp --ignore-scripts --no-audit --no-fund --save-exact '@ffmpeg/ffmpeg@0.12.15' '@ffmpeg/core@0.12.10'
    if ($LASTEXITCODE -ne 0) { throw 'npm install failed. Check internet access and retry.' }
    $wrapperPackage = Join-Path $temp 'node_modules/@ffmpeg/ffmpeg'
    $corePackage = Join-Path $temp 'node_modules/@ffmpeg/core'
    $stage = Join-Path $temp 'stage'
    New-Item -ItemType Directory -Path (Join-Path $stage 'wrapper'),(Join-Path $stage 'core') -Force | Out-Null
    Copy-Item -Path (Join-Path $wrapperPackage 'dist/esm/*') -Destination (Join-Path $stage 'wrapper') -Recurse -Force
    foreach ($file in @('ffmpeg-core.js','ffmpeg-core.wasm')) {
        Copy-Item (Join-Path $corePackage ('dist/esm/' + $file)) (Join-Path $stage 'core') -Force
    }
    foreach ($package in @(@{Root=$wrapperPackage;Dir='wrapper'},@{Root=$corePackage;Dir='core'})) {
        Get-ChildItem -LiteralPath $package.Root -File | Where-Object { $_.Name -match '^(LICENSE|COPYING|NOTICE|README)' } |
            Copy-Item -Destination (Join-Path $stage $package.Dir) -Force
    }
    foreach ($file in $required) {
        if (-not (Test-Path (Join-Path $stage $file))) { throw "Engine asset missing: $file" }
    }
    Set-Content -Path (Join-Path $stage 'versions.txt') -Value $versions -Encoding ASCII
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    if (Test-Path $stamp) { Remove-Item $stamp -Force }
    Copy-Item -Path (Join-Path $stage 'wrapper'),(Join-Path $stage 'core') -Destination $target -Recurse -Force
    Copy-Item -Path (Join-Path $stage 'versions.txt') -Destination $target -Force
    Write-Host 'Browser audio engine installed. Restart flutter run -d chrome.'
} finally {
    if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
