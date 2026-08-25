#!/usr/bin/env pwsh

# claude-cli-setup.ps1 - Interactive setup for Anthropic Claude Code CLI
# Configures ANTHROPIC_* environment variables into the PowerShell profile

# Ensure an interactive terminal
if (-not [console]::IsInputRedirected) {
    # Normal interactive terminal, no extra action needed
} else {
    Write-Host "Error: Please run this script in an interactive terminal." -ForegroundColor Red
    exit 1
}

# -------- Utility functions --------
function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command -Name $Command -ErrorAction SilentlyContinue)
}

function Test-Trim {
    param([string]$String)
    return $String.Trim()
}

function Read-TTY {
    param([string]$Prompt)
    $input = Read-Host -Prompt $Prompt -ErrorAction SilentlyContinue
    return $input
}

function Read-SecretTTY {
    param([string]$Prompt)
    $input = Read-Host -Prompt $Prompt -AsSecureString -ErrorAction SilentlyContinue
    if ($input) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($input)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    return ""
}

function Get-SingleQuote {
    param([string]$String)
    return "'$($String -replace "'", "''")'"
}

# Read a value from environment variables, checking both process and user scope
function Get-EnvironmentVariableValue {
    param([string]$Key)

    if (-not $Key) {
        return ""
    }

    # First try the current process
    $value = [Environment]::GetEnvironmentVariable($Key, 'Process')
    if (-not [string]::IsNullOrEmpty($value)) {
        return $value
    }

    # Then try the user environment
    $value = [Environment]::GetEnvironmentVariable($Key, 'User')
    if (-not [string]::IsNullOrEmpty($value)) {
        return $value
    }

    return ""
}

# Extract the hostname from a URL
function Get-HostFromUrl {
    param([string]$Url)

    if (-not $Url) {
        return ""
    }

    # Remove the protocol (http:// or https://)
    $hostPart = $Url -replace '^https?://', ''
    # Take the part before the first slash
    $hostPart = $hostPart -split '/', 2 | Select-Object -First 1

    return $hostPart
}

# Ensure the URL includes a scheme
function Ensure-Scheme {
    param([string]$Url)

    if (-not $Url) {
        return ""
    }

    # Ensure the base_url includes a scheme; default to https
    if ($Url -match '^https?://') {
        return $Url
    } else {
        return "https://$Url"
    }
}

# Prompt for a new API URL
function Get-NewApiUrl {
    param(
        [string]$AppLabel = "Anthropic Claude Code CLI",
        [string]$BaseSuffix = "",
        [string]$ExistingBaseUrl = ""
    )

    $exampleUrl = "https://your-new-api-site$BaseSuffix"

    Write-Host ""
    Write-Host "Currently only a custom $AppLabel API site is supported."
    Write-Host "Example: $exampleUrl"

    if (-not [string]::IsNullOrEmpty($ExistingBaseUrl)) {
        Write-Host "Tip: Press Enter to keep the existing base_url unchanged (current: $ExistingBaseUrl)"
        $choice = Read-TTY "Press Enter to keep it, or type 'y' to enter a custom value: "

        if ($choice -ne 'y' -and $choice -ne 'Y') {
            Write-Host "Keeping existing base_url: $ExistingBaseUrl"
            return $ExistingBaseUrl
        }
    }

    # Force the custom input flow
    Write-Host ""
    Write-Host "Please enter the full base_url (starting with http(s)://)."
    Write-Host "Example: $exampleUrl"

    do {
        $customUrl = Read-TTY "Custom base_url: "
        $customUrl = Test-Trim $customUrl

        if ([string]::IsNullOrEmpty($customUrl)) {
            Write-Host "Error: base_url cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrEmpty($customUrl))

    $customUrl = Ensure-Scheme $customUrl
    return $customUrl
}

# Prompt for an API token
function Get-ApiToken {
    param(
        [string]$TokenLabel = "ANTHROPIC_AUTH_TOKEN",
        [string]$Hostname = ""
    )

    $tokenUrl = "https://$Hostname/console/token"

    Write-Host ""
    Write-Host "Please visit the following URL in your browser to obtain your ${TokenLabel}:"
    Write-Host "  $tokenUrl"
    Write-Host "Once obtained, paste your ${TokenLabel}:"

    do {
        $tokenInput = Read-SecretTTY "Paste your ${TokenLabel}: "
        $tokenInput = Test-Trim $tokenInput

        # Remove any internal CR/LF characters
        $tokenInput = $tokenInput -replace "[\r\n]", ""

        if ([string]::IsNullOrEmpty($tokenInput)) {
            Write-Host "Error: ${TokenLabel} cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrEmpty($tokenInput))

    return $tokenInput
}

# Main function
function Main {
    Write-Host "=== Anthropic Claude Code CLI Setup Tool ==="
    Write-Host ""

    # Read existing configuration
    $existingBase = Get-EnvironmentVariableValue "ANTHROPIC_BASE_URL"
    $existingKey = Get-EnvironmentVariableValue "ANTHROPIC_AUTH_TOKEN"

    # Prompt for a new API URL
    $newBaseUrl = Get-NewApiUrl "Anthropic Claude Code CLI" "" $existingBase

    # Prompt for an API token
    $hostForToken = Get-HostFromUrl $newBaseUrl
    if ([string]::IsNullOrEmpty($hostForToken)) {
        Write-Host "Error: Unable to extract hostname from base_url '$newBaseUrl'." -ForegroundColor Red
        exit 1
    }

    $newApiKey = Get-ApiToken "ANTHROPIC_AUTH_TOKEN" $hostForToken

    # Set environment variables directly, consistent with example.ps1
    [Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', $newBaseUrl, 'User')
    [Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', $newApiKey, 'User')

    # Also set them for the current process so they take effect immediately
    $env:ANTHROPIC_BASE_URL = $newBaseUrl
    $env:ANTHROPIC_AUTH_TOKEN = $newApiKey

    Write-Host ""
    Write-Host "✅ Anthropic Claude Code CLI setup complete." -ForegroundColor Green
    Write-Host "  ANTHROPIC_BASE_URL: $newBaseUrl $(if ($newBaseUrl -eq $existingBase) { "(unchanged)" } else { "(custom)" })"
    Write-Host "  ANTHROPIC_AUTH_TOKEN: $(if ($newApiKey -eq $existingKey) { "unchanged" } else { "updated" })"
    Write-Host ""
    Write-Host "Tip: Open a new PowerShell window, or the settings are already active in the current session."
    Write-Host ""
    Write-Host "Note: Configuration takes effect via environment variables; no extra config file is needed."
}

# Run the main function
Main
