# Function to get extension names and IDs for a given browser
function Get-Extensions {
    param (
        [string]$ExtensionsPath,
        [string]$ManifestFileName = "manifest.json"
    )

    $Extensions = @()
    $ExtensionIDs = Get-ChildItem -Path $ExtensionsPath -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name

    foreach ($ExtensionID in $ExtensionIDs) {
        # Check if the extension's manifest file exists in the expected directory
        $ManifestPath = Join-Path -Path $ExtensionsPath -ChildPath "$ExtensionID\$ManifestFileName"
        if (-not (Test-Path $ManifestPath)) {
            # Sometimes extensions may store the manifest file in a subfolder, try to find it
            $SubDirectories = Get-ChildItem -Path (Join-Path -Path $ExtensionsPath -ChildPath $ExtensionID) -Directory -ErrorAction SilentlyContinue
            foreach ($SubDir in $SubDirectories) {
                $ManifestPath = Join-Path -Path $SubDir.FullName -ChildPath $ManifestFileName
                if (Test-Path $ManifestPath) { break }
            }
        }

        if (Test-Path $ManifestPath) {
            try {
                # Attempt to read the manifest.json file
                $ManifestContent = Get-Content -Path $ManifestPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                $Extensions += [PSCustomObject]@{
                    Name = $ManifestContent.name
                    ID = $ExtensionID
                }
            } catch {
                # Handle JSON parsing or file read errors
                $Extensions += [PSCustomObject]@{
                    Name = "Unknown Extension (Error reading manifest)"
                    ID = $ExtensionID
                }
            }
        } else {
            # If the manifest file is not found
            $Extensions += [PSCustomObject]@{
                Name = "Unknown Extension (Manifest not found)"
                ID = $ExtensionID
            }
        }
    }

    return $Extensions
}

# Computer Name
$ComputerName = $env:COMPUTERNAME

# Edge Extensions
$EdgeExtensionsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
if (Test-Path $EdgeExtensionsPath) {
    $EdgeExtensions = Get-Extensions -ExtensionsPath $EdgeExtensionsPath
}

# Chrome Extensions
$ChromeExtensionsPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
if (Test-Path $ChromeExtensionsPath) {
    $ChromeExtensions = Get-Extensions -ExtensionsPath $ChromeExtensionsPath
}

# Firefox Extensions
$FirefoxProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $FirefoxProfilePath) {
    $Profile = Get-ChildItem -Path $FirefoxProfilePath -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    $FirefoxExtensionsPath = Join-Path -Path $Profile.FullName -ChildPath "extensions"
    $FirefoxExtensions = Get-Extensions -ExtensionsPath $FirefoxExtensionsPath -ManifestFileName "manifest.json"
}

# Combine all extensions
$AllExtensions = $EdgeExtensions + $ChromeExtensions + $FirefoxExtensions

# Add computer name to each extension entry
$AllExtensionsWithComputer = $AllExtensions | ForEach-Object {
    [PSCustomObject]@{
        ComputerName = $ComputerName
        Name = $_.Name
        ID = $_.ID
    }
}

# Output all extensions
$AllExtensionsWithComputer | ForEach-Object { Write-Output "Computer: $($_.ComputerName), Name: $($_.Name), ID: $($_.ID)" }

# Define the CSV path
$CSVPath = "\\IP_Address\Public Share\Browser_Extensions.csv"

# Check if the CSV file exists, if not, create it with headers
if (-not (Test-Path $CSVPath)) {
    $AllExtensionsWithComputer | Export-Csv -Path $CSVPath -NoTypeInformation
} else {
    # Append data to the CSV file
    $AllExtensionsWithComputer | Export-Csv -Path $CSVPath -NoTypeInformation -Append
}
