[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempParent = [IO.Path]::GetTempPath()
$tempRoot = Join-Path $tempParent ("STEP-package-test-" + $PID)
$resolvedTempParent = [IO.Path]::GetFullPath($tempParent)
$resolvedTempRoot = [IO.Path]::GetFullPath($tempRoot)

if (-not $resolvedTempRoot.StartsWith($resolvedTempParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe package test path: $resolvedTempRoot"
}

$runtimeFiles = @("STEP.toc")
$tocPath = Join-Path $repoRoot "STEP.toc"
foreach ($line in Get-Content -LiteralPath $tocPath) {
    $relative = $line.Trim()
    if ($relative -and -not $relative.StartsWith("#")) {
        $relative = $relative.Replace("\", [IO.Path]::DirectorySeparatorChar).Replace("/", [IO.Path]::DirectorySeparatorChar)
        $runtimeFiles += $relative
    }
}

try {
    $packageRoot = Join-Path $tempRoot "package\STEP"
    $inspectRoot = Join-Path $tempRoot "inspect"
    $zipPath = Join-Path $tempRoot "STEP.zip"

    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

    foreach ($file in $runtimeFiles) {
        $source = Join-Path $repoRoot $file
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Missing runtime file: $file"
        }
        $destination = Join-Path $packageRoot $file
        $destinationDirectory = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $destination
    }

    Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $inspectRoot

    $entries = Get-ChildItem -LiteralPath $inspectRoot -Recurse -File
    if ($entries.Count -eq 0) {
        throw "The generated ZIP is empty."
    }

    $topLevelPrefix = "STEP" + [IO.Path]::DirectorySeparatorChar
    foreach ($entry in $entries) {
        $relative = $entry.FullName.Substring($inspectRoot.Length + 1)
        if (-not $relative.StartsWith($topLevelPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "ZIP entry is outside the STEP top-level folder: $relative"
        }
        Write-Output $relative
    }

    if ($OutputPath) {
        if (-not [IO.Path]::IsPathRooted($OutputPath)) {
            $OutputPath = Join-Path $repoRoot $OutputPath
        }
        $resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
        $outputDirectory = Split-Path -Parent $resolvedOutputPath
        if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        Copy-Item -LiteralPath $zipPath -Destination $resolvedOutputPath -Force
        Write-Output "Package written to $resolvedOutputPath"
    }

    Write-Output ("Validated STEP.zip with {0} runtime files." -f $entries.Count)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
