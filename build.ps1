# --- Settings ---
$srcDir      = "./src"
$buildDir    = "./build"
$projectName = "HoverName"
$commonDocs  = @("./LICENSE", "./README.md")

# --- Prep ---
if (!(Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }

# Collect all *.toc variants (HoverName.toc, HoverName_*.toc)
$tocFiles = Get-ChildItem -Path $srcDir -Filter "$projectName*.toc" -File
if ($tocFiles.Count -eq 0) {
  Write-Error "No .toc files found in $srcDir"
  exit 1
}

$built = @()

foreach ($toc in $tocFiles) {
  # Derive suffix from TOC filename
  $base    = [IO.Path]::GetFileNameWithoutExtension($toc.Name)
  $suffix  = $base.Substring($projectName.Length)
  $display = if ([string]::IsNullOrWhiteSpace($suffix)) { "Retail" } else { $suffix.TrimStart("_") }

  # Read version from this TOC
  $versionPattern = '^\s*##\s*Version\s*:\s*(.+)$'
  $version = (Select-String -Path $toc.FullName -Pattern $versionPattern -AllMatches |
              Select-Object -First 1 -ExpandProperty Matches |
              ForEach-Object { $_.Groups[1].Value.Trim() })
  if ([string]::IsNullOrWhiteSpace($version)) { $version = "0.0.0" }

  # Temp working dirs
  $tempDir  = Join-Path $buildDir ("Temp_" + $projectName + $suffix)
  $addonDir = Join-Path $tempDir $projectName

  if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
  New-Item -ItemType Directory -Path $addonDir | Out-Null

  try {
    # Copy source
    Copy-Item -Path (Join-Path $srcDir "*") -Destination $addonDir -Recurse

    # Ensure only the selected TOC is present inside the package (renamed to HoverName.toc)
    Get-ChildItem -Path $addonDir -Filter "$projectName*.toc" -File | Remove-Item -Force
    Copy-Item -Path $toc.FullName -Destination (Join-Path $addonDir "$projectName.toc")

    # Always include common docs
    foreach ($doc in $commonDocs) {
      if (Test-Path $doc) { Copy-Item -Path $doc -Destination $addonDir -Force }
    }

    # Select changelog by SAME suffix as the TOC
    $changelog = if ([string]::IsNullOrWhiteSpace($suffix)) {
      "./CHANGELOG.md"
    } else {
      $candidate = ".\CHANGELOG$suffix.md"
      if (Test-Path $candidate) { $candidate } else { "./CHANGELOG.md" }
    }

    # Copy the chosen changelog INTO the package AS "CHANGELOG" (no extension)
    if (Test-Path $changelog) {
      Copy-Item -Path $changelog -Destination (Join-Path $addonDir "CHANGELOG.md") -Force
    } else {
      Write-Warning "Changelog not found ($changelog) for $display build. Skipping."
    }

    # ZIP name mirrors the TOC suffix (empty suffix => no suffix in name)
    $zipName = if ([string]::IsNullOrWhiteSpace($suffix)) {
      "$projectName-v$version.zip"
    } else {
      "$projectName-v$version$suffix.zip" 
    }


    $zipName = $zipName -replace "_", "-"
    $zipPath = Join-Path $buildDir $zipName
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zipPath -Force

    $built += $zipName
  }
  finally {
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
  }
}

Write-Host ""
Write-Host "Output:" -ForegroundColor Cyan
$built | ForEach-Object { Write-Host " - $_" }
