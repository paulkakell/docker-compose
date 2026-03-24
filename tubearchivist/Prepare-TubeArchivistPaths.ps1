param(
    [string]$EnvFile = ".env"
)

Write-Host "Reading environment file: $EnvFile"

if (!(Test-Path $EnvFile)) {
    Write-Error "Environment file not found."
    exit 1
}

# Read .env and extract key=value pairs
$envVars = Get-Content $EnvFile | Where-Object {
    $_ -match "=" -and -not $_.StartsWith("#")
}

$paths = @()

foreach ($line in $envVars) {
    $parts = $line -split "=", 2
    if ($parts.Count -ne 2) { continue }

    $value = $parts[1].Trim()

    # Detect Windows-style absolute paths
    if ($value -match "^[A-Za-z]:\\") {
        $paths += $value
    }
}

if ($paths.Count -eq 0) {
    Write-Host "No Windows paths found in .env"
    exit 0
}

$paths = $paths | Sort-Object -Unique

Write-Host "Discovered paths:"
$paths | ForEach-Object { Write-Host " - $_" }

foreach ($path in $paths) {

    Write-Host "`nProcessing: $path"

    try {
        # Create directory if it does not exist
        if (!(Test-Path $path)) {
            Write-Host "Creating directory..."
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        } else {
            Write-Host "Directory already exists."
        }

        # Remove read-only attribute
        Write-Host "Clearing read-only flags..."
        attrib -r $path /s /d 2>$null

        # Grant permissions (Users + Everyone full control)
        Write-Host "Setting permissions..."
        icacls $path /grant "Users:(OI)(CI)F" /T /C | Out-Null
        icacls $path /grant "Everyone:(OI)(CI)F" /T /C | Out-Null

        # Ensure inheritance is enabled
        icacls $path /inheritance:e | Out-Null

        Write-Host "Completed: $path"

    } catch {
        Write-Warning "Failed to process $path : $_"
    }
}

Write-Host "`nDone."
