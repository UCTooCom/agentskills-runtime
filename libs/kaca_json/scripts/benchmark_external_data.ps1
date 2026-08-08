param(
    [ValidateSet("internal", "external", "both")]
    [string]$Source = "external",
    [ValidateSet("parse", "materialize", "both")]
    [string]$Mode = "both",
    [string]$DataDir = ".\\data\\cjfast",
    [string[]]$Parsers = @("standard", "fast"),
    [string[]]$Datasets = @("small", "medium", "large"),
    [string[]]$Files = @(),
    [int]$Repeats = 3
)

function Split-CsvArg([string[]]$items) {
    if ($items.Count -eq 1 -and $items[0].Contains(',')) {
        return $items[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
    return $items
}

$Parsers = Split-CsvArg $Parsers
$Datasets = Split-CsvArg $Datasets
$Files = Split-CsvArg $Files

$cjpmToml = Join-Path $PSScriptRoot "..\\cjpm.toml"
if (Test-Path $cjpmToml) {
    $tomlText = Get-Content -Raw $cjpmToml
    if ($tomlText -match 'output-type\\s*=\\s*\"static\"') {
        throw "benchmark script requires executable mode; current package output-type is static (library mode)."
    }
}

$internalParseIterations = @{
    small = 10000
    medium = 3000
    large = 200
}

$internalMaterializeIterations = @{
    small = 6000
    medium = 1200
    large = 120
}

$externalIterationMap = @{
    simple = 10000
    medium = 5000
    complex = 2000
    twitter = 100
}

function Get-ExternalIterations([string]$fileName, [int64]$bytes) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName).ToLower()
    if ($externalIterationMap.ContainsKey($base)) {
        return [int]$externalIterationMap[$base]
    }
    if ($bytes -lt 2048) { return 5000 }
    if ($bytes -lt 65536) { return 1000 }
    return 100
}

function Invoke-Bench([string]$runArgs, [string]$context) {
    $output = cjpm run --run-args $runArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "benchmark failed: $context`n$output"
    }
    $resultLine = $output | Select-String "^RESULT " | Select-Object -Last 1
    if (-not $resultLine) {
        throw "missing RESULT line: $context`n$output"
    }
    if ($resultLine.Line -match "time_ms=([0-9.]+) mbps=([0-9.]+)") {
        return [pscustomobject]@{
            TimeMs = [double]$matches[1]
            MBps = [double]$matches[2]
        }
    }
    throw "unrecognized RESULT format: $($resultLine.Line)"
}

function Get-BenchModes([string]$mode, [string]$source) {
    if ($source -eq "internal") {
        if ($mode -eq "parse") { return @("bench-one") }
        if ($mode -eq "materialize") { return @("bench-one-materialize") }
        return @("bench-one", "bench-one-materialize")
    }
    if ($mode -eq "parse") { return @("bench-file") }
    if ($mode -eq "materialize") { return @("bench-file-materialize") }
    return @("bench-file", "bench-file-materialize")
}

$rows = @()

if ($Source -eq "internal" -or $Source -eq "both") {
    $benchModes = Get-BenchModes $Mode "internal"
    foreach ($benchMode in $benchModes) {
        foreach ($dataset in $Datasets) {
            if (-not $internalParseIterations.ContainsKey($dataset)) {
                throw "unknown internal dataset: $dataset (supported: small, medium, large)"
            }
            $iterations = if ($benchMode -eq "bench-one") {
                $internalParseIterations[$dataset]
            } else {
                $internalMaterializeIterations[$dataset]
            }
            foreach ($parser in $Parsers) {
                $samples = @()
                for ($i = 0; $i -lt $Repeats; $i++) {
                    $runArgs = "$benchMode $parser $dataset $iterations"
                    $context = "source=internal mode=$benchMode parser=$parser dataset=$dataset"
                    $samples += (Invoke-Bench $runArgs $context)
                }
                $medianSample = $samples | Sort-Object TimeMs | Select-Object -Index ([int]($samples.Count / 2))
                $rows += [pscustomobject]@{
                    Source = "internal"
                    Mode = if ($benchMode -eq "bench-one") { "parse" } else { "materialize" }
                    DataSet = $dataset
                    Bytes = "-"
                    Parser = $parser
                    Iterations = $iterations
                    MedianMs = [math]::Round($medianSample.TimeMs, 3)
                    MedianMBps = [math]::Round($medianSample.MBps, 3)
                }
            }
        }
    }
}

if ($Source -eq "external" -or $Source -eq "both") {
    $benchModes = Get-BenchModes $Mode "external"
    $allFiles = Get-ChildItem -Path $DataDir -File -Filter *.json | Sort-Object Name
    if (-not $allFiles -or $allFiles.Count -eq 0) {
        throw "no json files found in $DataDir"
    }

    $targetFiles = if ($Files.Count -eq 0) {
        $allFiles
    } else {
        $lookup = @{}
        foreach ($f in $allFiles) {
            $lookup[[System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLower()] = $f
            $lookup[$f.Name.ToLower()] = $f
        }
        $selected = @()
        foreach ($name in $Files) {
            $key = $name.ToLower()
            if (-not $lookup.ContainsKey($key)) {
                throw "external file not found: $name (use base name like 'twitter' or full file name)"
            }
            $selected += $lookup[$key]
        }
        $selected
    }

    foreach ($benchMode in $benchModes) {
        foreach ($file in $targetFiles) {
            $iterations = Get-ExternalIterations $file.Name $file.Length
            foreach ($parser in $Parsers) {
                $samples = @()
                for ($i = 0; $i -lt $Repeats; $i++) {
                    $runArgs = "$benchMode $parser `"$($file.FullName)`" $iterations"
                    $context = "source=external mode=$benchMode parser=$parser file=$($file.FullName)"
                    $samples += (Invoke-Bench $runArgs $context)
                }
                $medianSample = $samples | Sort-Object TimeMs | Select-Object -Index ([int]($samples.Count / 2))
                $rows += [pscustomobject]@{
                    Source = "external"
                    Mode = if ($benchMode -eq "bench-file") { "parse" } else { "materialize" }
                    DataSet = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    Bytes = [int64]$file.Length
                    Parser = $parser
                    Iterations = $iterations
                    MedianMs = [math]::Round($medianSample.TimeMs, 3)
                    MedianMBps = [math]::Round($medianSample.MBps, 3)
                }
            }
        }
    }
}

$rows |
    Sort-Object Source, Mode, DataSet, @{ Expression = "MedianMBps"; Descending = $true } |
    Format-Table -AutoSize

