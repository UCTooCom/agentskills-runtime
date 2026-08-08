param(
    [switch]$WithBench
)

$ErrorActionPreference = "Stop"

Write-Host "[ci] cjpm build"
cjpm build

Write-Host "[ci] cjpm test"
cjpm test

if ($WithBench) {
    Write-Host "[ci] cjpm bench --no-color"
    cjpm bench --no-color
}

Write-Host "[ci] done"
