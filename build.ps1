# Set variables
$srcDir = "./src"
$buildDir = "./build"
$projectName = "HoverName"
$tocFile = "$srcDir/$projectName.toc"
$versionPattern = "## Version: "
$version = ""

# Read the version from the .toc file
Get-Content $tocFile | ForEach-Object {
    if ($_ -match "$versionPattern") {
        $version = $_.Substring($versionPattern.Length).Trim()
    }
}

# Set the zip file name
$zipName = "$projectName-v$version.zip"
$zipPath = "$buildDir/$zipName"

# Ensure build directory exists
if (!(Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir
}

# Create temporary directory for zipping
$tempDir = New-Item -ItemType Directory -Path (Join-Path $buildDir "TempHoverDir")

# Create HoverName directory inside temporary directory
$hoverDir = New-Item -ItemType Directory -Path (Join-Path $tempDir $projectName)

# Copy files from src directory to HoverName directory
Copy-Item -Path "$srcDir\*" -Destination $hoverDir -Recurse

# Copy specific files to HoverName directory
$specificFiles = @("./CHANGELOG.md", "./LICENSE", "./README.md")
foreach ($file in $specificFiles) {
  Copy-Item -Path $file -Destination $hoverDir
}

# Create the zip file
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

# Clean up temporary directory
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "$zipName has been created in the build directory."