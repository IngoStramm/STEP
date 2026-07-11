[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempRoot = Join-Path $env:TEMP ("STEP-package-test-" + $PID)
$resolvedTempParent = [IO.Path]::GetFullPath($env:TEMP)
$resolvedTempRoot = [IO.Path]::GetFullPath($tempRoot)

if (-not $resolvedTempRoot.StartsWith($resolvedTempParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe package test path: $resolvedTempRoot"
}

$runtimeFiles = @(
    "STEP.toc",
    "Core.lua",
    "Constants.lua",
    "Util.lua",
    "SlashCommands.lua"
)

$runtimeDirectories = @(
    "Locale",
    "Data",
    "Services"
)

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
        Copy-Item -LiteralPath $source -Destination $packageRoot
    }

    foreach ($directory in $runtimeDirectories) {
        $source = Join-Path $repoRoot $directory
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "Missing runtime directory: $directory"
        }
        Copy-Item -LiteralPath $source -Destination $packageRoot -Recurse
    }

    Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $inspectRoot

    $entries = Get-ChildItem -LiteralPath $inspectRoot -Recurse -File
    if ($entries.Count -eq 0) {
        throw "The generated ZIP is empty."
    }

    foreach ($entry in $entries) {
        $relative = $entry.FullName.Substring($inspectRoot.Length + 1)
        if (-not $relative.StartsWith("STEP\", [StringComparison]::OrdinalIgnoreCase)) {
            throw "ZIP entry is outside the STEP top-level folder: $relative"
        }
        Write-Output $relative
    }

    Write-Output ("Validated STEP.zip with {0} runtime files." -f $entries.Count)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
