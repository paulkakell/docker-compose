param(
    [string]$EnvFile = "EnvironmentSettings.txt"
)

$requiredKeys = @(
    "TA_CACHE_PATH",
    "TA_MEDIA_PATH",
    "REDIS_DATA_PATH",
    "ES_DATA_PATH",
    "ES_SNAPSHOT_PATH"
)

Write-Host "Reading environment file: $EnvFile"

if (!(Test-Path $EnvFile)) {
    Write-Error "Environment file not found."
    exit 1
}

# Parse .env file into dictionary
$envMap = @{}

Get-Content $EnvFile | ForEach-Object {
    if ($_ -match "=" -and -not $_.StartsWith("#")) {
        $parts = $_ -split "=", 2
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            $envMap[$key] = $value
        }
    }
}

$paths = @()

foreach ($key in $requiredKeys) {
    if ($envMap.ContainsKey($key)) {
        $value = $envMap[$key]

        if ($value -match "^[A-Za-z]:\\") {
            $paths += $value
        } else {
            Write-Warning "$key is not a valid Windows path: $value"
        }
    } else {
        Write-Warning "$key not found in env file"
    }
}

if ($paths.Count -eq 0) {
    Write-Error "No valid paths found."
    exit 1
}

$paths = $paths | Sort-Object -Unique

Write-Host "`nPaths to prepare:"
$paths | ForEach-Object { Write-Host " - $_" }

foreach ($path in $paths) {

    Write-Host "`nProcessing: $path"

    try {
        # Create directory if missing
        if (!(Test-Path $path)) {
            Write-Host "Creating directory..."
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        } else {
            Write-Host "Directory already exists."
        }

        # Remove read-only attributes
        Write-Host "Clearing read-only flags..."
        attrib -r "$path\*" /s /d 2>$null

        # Enable inheritance
        icacls $path /inheritance:e | Out-Null

        # Grant Docker-friendly permissions
        Write-Host "Setting permissions..."
        icacls $path /grant "Users:(OI)(CI)F" /T /C | Out-Null
        icacls $path /grant "Everyone:(OI)(CI)F" /T /C | Out-Null

        Write-Host "Completed: $path"

    } catch {
        Write-Warning "Failed to process $path : $_"
    }
}

Write-Host "`nAll paths processed."
