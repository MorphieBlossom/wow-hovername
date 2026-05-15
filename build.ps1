# --- Settings ---
$srcDir      = "./src"
$buildDir    = "./build"
$projectName = "HoverName"
$commonDocs  = @("./LICENSE", "./README.md")

# --- Prep ---
if (!(Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }

# Update CHANGELOG.md from src/Modules/Changelog.lua if there are missing entries
function Update-ChangelogFromLua {
  param(
    [string]$LuaPath = "./src/Modules/Changelog.lua",
    [string]$ChangelogPath = "./CHANGELOG.md"
  )

  if (!(Test-Path $LuaPath)) { Write-Verbose "Lua changelog not found: $LuaPath"; return }
  if (!(Test-Path $ChangelogPath)) { Write-Verbose "Markdown changelog not found: $ChangelogPath"; return }

  $lua = Get-Content -Raw $LuaPath
  $md  = Get-Content -Raw $ChangelogPath

  # Find existing versions in the markdown
  $existing = @()
  [regex]::Matches($md, '### `(?<v>[^`]+)`') | ForEach-Object { $existing += $_.Groups['v'].Value }

  # Locate the changelog data block. Supports both styles:
  #   addon.MBLib.Changelog:Set({ ... })       (MBLib-integrated)
  #   Changelog.list = { ... }                  (legacy)
  # Anchoring the version scan to this block prevents picking up unrelated
  # 'version = "..."' strings elsewhere in the file.
  $blockOpenMatch = [regex]::Match($lua, '(?:Changelog:Set\s*\(\s*|Changelog\.list\s*=\s*)\{')
  if (-not $blockOpenMatch.Success) {
    Write-Warning "Could not locate Changelog data block in $LuaPath (expected 'Changelog:Set({' or 'Changelog.list = {'). Skipping changelog sync."
    return
  }
  $blockStart = $blockOpenMatch.Index + $blockOpenMatch.Length - 1  # position of the opening '{'
  $depth0 = 0
  $blockEnd = -1
  for ($k = $blockStart; $k -lt $lua.Length; $k++) {
    switch ($lua[$k]) {
      '{' { $depth0++ }
      '}' { $depth0-- }
    }
    if ($depth0 -eq 0) { $blockEnd = $k; break }
  }
  if ($blockEnd -lt 0) {
    Write-Warning "Unterminated Changelog data block in $LuaPath; skipping changelog sync."
    return
  }
  $luaBlock = $lua.Substring($blockStart, $blockEnd - $blockStart + 1)

  # Parse entries by locating each 'version = "..."' inside the block and extracting
  # the enclosing table via brace counting.
  $versionRegex = 'version\s*=\s*"(?<version>[^"]+)"'
  $verMatches = [regex]::Matches($luaBlock, $versionRegex)
  $lua = $luaBlock  # remainder of function operates on the block

  $newBlocks = ""
  foreach ($vm in $verMatches) {
    $ver = $vm.Groups['version'].Value
    if ($existing -contains $ver) { continue }

    # Find the opening brace for this entry (search backward)
    $entryOpen = $lua.LastIndexOf('{', $vm.Index)
    if ($entryOpen -lt 0) { continue }

    # Find the matching closing brace for the entry
    $depth = 0
    $entryEnd = -1
    for ($i = $entryOpen; $i -lt $lua.Length; $i++) {
      switch ($lua[$i]) {
        '{' { $depth++ }
        '}' { $depth-- }
      }
      if ($depth -eq 0) { $entryEnd = $i; break }
    }
    if ($entryEnd -lt 0) { continue }

    $entryText = $lua.Substring($entryOpen, $entryEnd - $entryOpen + 1)

    # Extract date
    $dateMatch = [regex]::Match($entryText, 'date\s*=\s*"(?<date>[^"]+)"')
    $date = if ($dateMatch.Success) { $dateMatch.Groups['date'].Value } else { '' }

    # Extract categories block
    $catsText = ''
    $catsPos = $entryText.IndexOf('categories')
    if ($catsPos -ge 0) {
      $catsBrace = $entryText.IndexOf('{', $catsPos)
      if ($catsBrace -ge 0) {
        $depth2 = 0
        $catEnd = -1
        for ($j = $catsBrace; $j -lt $entryText.Length; $j++) {
          switch ($entryText[$j]) { '{' { $depth2++ } '}' { $depth2-- } }
          if ($depth2 -eq 0) { $catEnd = $j; break }
        }
        if ($catEnd -ge 0) { $catsText = $entryText.Substring($catsBrace + 1, $catEnd - $catsBrace - 1) }
      }
    }

    # Normalize single quotes to double quotes to simplify regex
    $catsTextNorm = $catsText -replace "'", '"'

    # Parse categories like ["New"] = { "item1", "item2", },
    $catPattern = '(?s)\[\s*"(?<cat>[^"]+)"\s*\]\s*=\s*\{(?<items>.*?)\}'
    $cats = [regex]::Matches($catsTextNorm, $catPattern)

    $block = '### `' + $ver + '` (' + $date + ')'+ "`r`n"
    foreach ($c in $cats) {
      $catName = $c.Groups['cat'].Value
      $heading = "**$catName**"
      $block += $heading + "`r`n"
      $itemsText = $c.Groups['items'].Value
      $itemPattern = '"(?<item>[^"]*?)"\s*,?'
      $items = [regex]::Matches($itemsText, $itemPattern)
      foreach ($it in $items) {
        $item = $it.Groups['item'].Value.Trim()
        if ($item -ne '') { $block += '- ' + $item + "`r`n" }
      }

      $block += "`r`n"
    }

    $newBlocks += $block + "---`r`n"
  }

  if ($newBlocks -eq '') { Write-Host "No new changelog entries found in $LuaPath"; return }

  # Insert new blocks after the first '---' separator in the markdown
  $mSep = [regex]::Match($md, '---\r?\n')
  if ($mSep.Success) {
    $insertPos = $mSep.Index + $mSep.Length
    $mdUpdated = $md.Substring(0, $insertPos) + $newBlocks + $md.Substring($insertPos)
  } else {
    $mdUpdated = $md + "`r`n" + $newBlocks
  }

  $mdUpdated = $mdUpdated -replace "(\r?\n)+\z", ""
  Set-Content -LiteralPath $ChangelogPath -Value $mdUpdated -Encoding UTF8
  $added = [regex]::Matches($newBlocks, '### `(?<v>[^`]+)`') | ForEach-Object { $_.Groups['v'].Value }
  Write-Host "Added changelog entries for versions: $($added -join ', ')"
}

# Sync the version + badge fields in README.md from a {flavor -> version} map.
# Each README heading is of the form:
#   ### Version 12.0.5.1 - available for World of Warcraft ![Version](https://img.shields.io/badge/version-12.0.5-blue)
# The full version updates the heading; the first three dot-separated segments
# update the shields.io badge URL. Mists flavor lines are matched by the extra
# 'Mists of Pandaria Classic' text in the heading.
function Update-ReadmeFromTocs {
  param(
    [string]$ReadmePath = "./README.md",
    [hashtable]$Versions
  )

  if (!(Test-Path $ReadmePath)) { Write-Verbose "README not found: $ReadmePath"; return }
  if (-not $Versions -or $Versions.Count -eq 0) { return }

  # PS 5.1's Get-Content -Raw on a no-BOM UTF-8 file decodes as Windows-1252 by default,
  # corrupting any non-ASCII bytes (e.g. emoji) before we even start. Use .NET I/O with
  # explicit UTF-8 to round-trip safely.
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  $content   = [System.IO.File]::ReadAllText($ReadmePath, [System.Text.Encoding]::UTF8)
  $original  = $content
  $missing   = @()

  foreach ($flavor in $Versions.Keys) {
    $fullVer = $Versions[$flavor]
    $parts   = $fullVer -split '\.'
    $shortVer = if ($parts.Count -ge 3) { ($parts[0..2] -join '.') } else { $fullVer }

    if ($flavor -eq 'Retail') {
      $pattern = '(?m)^(### Version )([\d\.]+)( - available for World of Warcraft )(!\[Version\]\(https://img\.shields\.io/badge/version-)([\d\.]+)(-blue\))'
    } else {
      $pattern = '(?m)^(### Version )([\d\.]+)( - available for World of Warcraft - ' + [regex]::Escape($flavor) + '[^!]*)(!\[Version\]\(https://img\.shields\.io/badge/version-)([\d\.]+)(-blue\))'
    }

    if (-not [regex]::IsMatch($content, $pattern)) {
      $missing += $flavor
      continue
    }

    $replacement = '${1}' + $fullVer + '${3}${4}' + $shortVer + '${6}'
    $content = [regex]::Replace($content, $pattern, $replacement)
  }

  foreach ($m in $missing) {
    Write-Warning "No version heading found in $ReadmePath for flavor '$m' (expected a line containing '### Version ... for World of Warcraft' and either no 'Mists...' suffix for Retail or that suffix for the matching flavor)."
  }

  if ($content -ne $original) {
    [System.IO.File]::WriteAllText($ReadmePath, $content, $utf8NoBom)
    $updated = @($Versions.Keys | Where-Object { $missing -notcontains $_ })
    Write-Host "Updated README.md version heading(s): $($updated -join ', ')"
  } else {
    Write-Host "README.md already up to date"
  }
}

# Run update before packaging to ensure CHANGELOG.md is in sync
Update-ChangelogFromLua

# Collect all *.toc variants (HoverName.toc, HoverName_*.toc)
$tocFiles = Get-ChildItem -Path $srcDir -Filter "$projectName*.toc" -File
if ($tocFiles.Count -eq 0) {
  Write-Error "No .toc files found in $srcDir"
  exit 1
}

$built       = @()
$tocVersions = @{}

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
  $tocVersions[$display] = $version

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

# Sync the README.md version headings with the per-flavor versions read above
Update-ReadmeFromTocs -Versions $tocVersions

Write-Host ""
Write-Host "Output:" -ForegroundColor Cyan
$built | ForEach-Object { Write-Host " - $_" }
