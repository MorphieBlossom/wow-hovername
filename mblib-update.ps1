# mblib-update.ps1
# Update MBLib in this addon's source tree by fetching the build from the MBLib
# GitHub release. Also wires MBLib into the addon's load order:
#   - If <Target>/Libraries/Load_Libraries.xml exists, adds
#     <Include file="MBLib\MBLib.xml"/> to it (idempotent).
#   - Otherwise, adds 'Libraries\MBLib\MBLib.xml' to each .toc in <Target> at the
#     top of the file list (idempotent).
#
# Usage:
#   pwsh ./mblib-update.ps1                  # latest, into ./src
#   pwsh ./mblib-update.ps1 -Version 1.0.0
#   pwsh ./mblib-update.ps1 -Target ./src

[CmdletBinding()]
param(
  [string]$Version,
  [string]$Target = "./src"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = "MorphieBlossom/wow-mblib"
$headers = @{ "User-Agent" = "mblib-update.ps1" }

if (-not (Test-Path $Target)) {
  throw "Target path does not exist: $Target"
}
$libsDir  = Join-Path $Target "Libraries"
$mbLibDir = Join-Path $libsDir "MBLib"

# UTF-8 without BOM (avoids polluting consumer files)
function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText((Resolve-Path $Path).Path, $Content, $utf8NoBom)
}

# --- Locate release ---
if ($Version) {
  $tag = if ($Version -like "v*") { $Version } else { "v$Version" }
  $apiUrl = "https://api.github.com/repos/$repo/releases/tags/$tag"
} else {
  $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
}
Write-Host "Fetching $apiUrl"
$release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing
$asset = $release.assets | Where-Object { $_.name -like "MBLib-v*.zip" } | Select-Object -First 1
if (-not $asset) {
  throw "No MBLib-v*.zip asset found in release $($release.tag_name)"
}

# --- Download, extract, install ---
$tempDir = Join-Path $env:TEMP ("mblib-update-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
  $tempZip = Join-Path $tempDir $asset.name
  Write-Host ("Downloading {0} ({1:N1} KB)" -f $asset.name, ($asset.size / 1024))
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -Headers $headers -UseBasicParsing

  $extractDir = Join-Path $tempDir "extract"
  Expand-Archive -Path $tempZip -DestinationPath $extractDir
  $extractedMBLib = Join-Path $extractDir "MBLib"
  if (-not (Test-Path $extractedMBLib)) {
    throw "Unexpected archive layout: 'MBLib' folder not found inside $($asset.name)"
  }

  if (Test-Path $mbLibDir) { Remove-Item -Recurse -Force $mbLibDir }
  if (-not (Test-Path $libsDir)) { New-Item -ItemType Directory -Path $libsDir | Out-Null }
  Copy-Item -Path $extractedMBLib -Destination $libsDir -Recurse
  Write-Host "Installed MBLib $($release.tag_name) -> $mbLibDir" -ForegroundColor Green
}
finally {
  if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
}

# --- Wire into load order ---
$loadXmlPath = Join-Path $libsDir "Load_Libraries.xml"
if (Test-Path $loadXmlPath) {
  $content = Get-Content -Raw -LiteralPath $loadXmlPath
  if ($content -match 'file=["'']MBLib[\\/]MBLib\.xml["'']') {
    Write-Host "Load_Libraries.xml already references MBLib"
  } else {
    # Find closing </Ui> (preserve its indent), detect existing child indent
    $closeMatch = [regex]::Match($content, '(?m)^(?<indent>[ \t]*)</Ui>')
    if (-not $closeMatch.Success) {
      Write-Warning "Could not find </Ui> in $loadXmlPath; skipping wire-in"
    } else {
      $childMatch = [regex]::Match($content, '(?m)^(?<i>[ \t]+)<(?:Include|Script)\s')
      $childIndent = if ($childMatch.Success) { $childMatch.Groups['i'].Value } else { '  ' }
      $newLine = "$childIndent<Include file=`"MBLib\MBLib.xml`"/>`r`n"
      $insertAt = $closeMatch.Index
      $newContent = $content.Substring(0, $insertAt) + $newLine + $content.Substring($insertAt)
      Write-Utf8NoBom -Path $loadXmlPath -Content $newContent
      Write-Host "Added <Include> for MBLib to Load_Libraries.xml" -ForegroundColor Cyan
    }
  }
} else {
  # No central loader — wire directly into each .toc
  $tocFiles = Get-ChildItem -Path $Target -Filter "*.toc" -File
  if ($tocFiles.Count -eq 0) {
    Write-Warning "No .toc file found in $Target; MBLib is unpacked but not wired in"
  }
  foreach ($toc in $tocFiles) {
    $tocContent = Get-Content -Raw -LiteralPath $toc.FullName
    if ($tocContent -match '(?im)^\s*Libraries[\\/]MBLib[\\/]MBLib\.xml\s*$') {
      Write-Host "$($toc.Name) already references MBLib"
      continue
    }
    # Detect existing line endings (default to CRLF)
    $eol = if ($tocContent -match "`r`n") { "`r`n" } elseif ($tocContent -match "`n") { "`n" } else { "`r`n" }
    $lines = $tocContent -split "`r?`n"
    # Find first non-directive, non-comment, non-blank line; insert before it
    $insertAt = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $trim = $lines[$i].Trim()
      if ($trim -eq '' -or $trim.StartsWith('#')) { continue }
      $insertAt = $i
      break
    }
    if ($insertAt -eq -1) {
      # No file references yet — append at end (after any trailing blanks)
      $lines = @($lines) + 'Libraries\MBLib\MBLib.xml'
    } else {
      $before = if ($insertAt -gt 0) { $lines[0..($insertAt - 1)] } else { @() }
      $after  = $lines[$insertAt..($lines.Count - 1)]
      $lines  = @($before) + 'Libraries\MBLib\MBLib.xml' + @($after)
    }
    Write-Utf8NoBom -Path $toc.FullName -Content (($lines -join $eol))
    Write-Host "Added Libraries\MBLib\MBLib.xml to $($toc.Name)" -ForegroundColor Cyan
  }
}
