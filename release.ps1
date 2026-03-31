param(
    [string]$OutputDir = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "releases"),
    [switch]$DryRun,
    [switch]$SkipTag
)

$ErrorActionPreference = "Stop"
$Root             = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AddonName        = "DjinnisDataTexts"
$TocFile          = Join-Path $Root "$AddonName.toc"
$ReleaseNotesFile = Join-Path $Root "RELEASE_NOTES.md"
$ChangelogFile    = Join-Path $Root "CHANGELOG.md"

function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan    }
function Write-Success { param($m) Write-Host $m -ForegroundColor Green   }
function Write-Warn    { param($m) Write-Host $m -ForegroundColor Yellow  }
function Write-Err     { param($m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------------------
# 1. Read version from RELEASE_NOTES.md
# ---------------------------------------------------------------------------

if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Err "RELEASE_NOTES.md not found. Create it with a '## Version: x.y.z' line."
}

$rnContent     = Get-Content $ReleaseNotesFile -Raw
$versionMatch  = [regex]::Match($rnContent, '##\s+Version:\s*(\S+)')
if (-not $versionMatch.Success) {
    Write-Err "No '## Version: x.y.z' line found in RELEASE_NOTES.md."
}
$Version = $versionMatch.Groups[1].Value.TrimStart('v')
$Tag     = "v$Version"

Write-Info ""
Write-Info "=== DjinnisDataTexts Release: $Tag ==="
if ($DryRun) { Write-Warn "  DRY RUN - no files will be written, committed, or tagged" }
Write-Info ""

# ---------------------------------------------------------------------------
# 2. Validate TOC version matches
# ---------------------------------------------------------------------------

$tocContent      = Get-Content $TocFile -Raw
$tocVersionMatch = [regex]::Match($tocContent, '##\s+Version:\s*(\S+)')
if (-not $tocVersionMatch.Success) { Write-Err "No '## Version:' in $AddonName.toc." }
$tocVersion = $tocVersionMatch.Groups[1].Value.TrimStart('v')

if ($tocVersion -ne $Version) {
    Write-Err ("Version mismatch: RELEASE_NOTES.md=$Version but $AddonName.toc=$tocVersion. Update the .toc file first.")
}
Write-Info "  TOC version: $tocVersion  OK"

# ---------------------------------------------------------------------------
# 3. Check git state
# ---------------------------------------------------------------------------

$gitStatus  = & git -C $Root status --porcelain 2>&1
$dirtyFiles = $gitStatus | Where-Object { $_ -match '^\s*[MADRCU?]' -and $_ -notmatch '\.claude' }

if ($dirtyFiles) {
    Write-Warn "  Uncommitted changes detected:"
    $dirtyFiles | ForEach-Object { Write-Warn "    $_" }
    if (-not $DryRun) {
        Write-Err "Commit or stash all changes before releasing. Use -DryRun to preview without this check."
    }
}

$tagExists = & git -C $Root tag -l $Tag 2>&1
if ($tagExists -contains $Tag) {
    Write-Warn "  Tag '$Tag' already exists - auto-bumping patch version..."

    # Parse version parts and increment patch until tag is free
    $parts = $Version.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    do {
        $patch++
        $Version = "$major.$minor.$patch"
        $Tag     = "v$Version"
        $tagCheck = & git -C $Root tag -l $Tag 2>&1
    } while ($tagCheck -contains $Tag)

    Write-Success "  Bumped to: $Tag"

    # Update RELEASE_NOTES.md
    $rnContent = $rnContent -replace '(##\s+Version:\s*)\S+', "`${1}$Version"
    [System.IO.File]::WriteAllText($ReleaseNotesFile, $rnContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Success "  Updated RELEASE_NOTES.md"

    # Update .toc
    $tocContent = $tocContent -replace '(##\s+Version:\s*)\S+', "`${1}$Version"
    [System.IO.File]::WriteAllText($TocFile, $tocContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Success "  Updated $AddonName.toc"

    # Re-read release notes for changelog extraction
    $rnContent = Get-Content $ReleaseNotesFile -Raw
}

# ---------------------------------------------------------------------------
# 4. Extract release notes body
# ---------------------------------------------------------------------------

# Strip the instruction comment block, the top-level heading, and the Version header line
$notesBody = $rnContent -replace '(?s)<!--.*?-->\s*', ''
$notesBody = $notesBody -replace '(?m)^#\s+Release Notes\s*(\r?\n)?', ''
$notesBody = $notesBody -replace '(?m)^##\s+Version:.*(\r?\n)?', ''
$notesBody = $notesBody.Trim()

# ---------------------------------------------------------------------------
# 5. Prepend entry to CHANGELOG.md
# ---------------------------------------------------------------------------

$today          = (Get-Date).ToString("yyyy-MM-dd")
$changelogEntry = "## [$Version] - $today`r`n`r`n$notesBody`r`n"

if (-not $DryRun) {
    $existing  = ""
    if (Test-Path $ChangelogFile) { $existing = Get-Content $ChangelogFile -Raw }

    $separator = "`r`n---`r`n"
    $sepIndex  = $existing.IndexOf($separator)

    if ($sepIndex -ge 0) {
        $before      = $existing.Substring(0, $sepIndex + $separator.Length)
        $after       = $existing.Substring($sepIndex + $separator.Length)
        $newChangelog = $before + "`r`n" + $changelogEntry + "`r`n" + $after
    } else {
        $newChangelog = $existing + "`r`n---`r`n`r`n" + $changelogEntry
    }

    [System.IO.File]::WriteAllText($ChangelogFile, $newChangelog, (New-Object System.Text.UTF8Encoding $false))
    Write-Success "  CHANGELOG.md updated"
} else {
    Write-Warn "  [DryRun] Would prepend to CHANGELOG.md:"
    Write-Host $changelogEntry -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 6. Build the zip
# ---------------------------------------------------------------------------

$ExcludeNames = @(
    "DjinnisDataTextsDB.lua"
    ".git"
    ".gitignore"
    ".claude"
    "CLAUDE.md"
    "Docs"
    "README.md"
    "ARTWORK_PROMPTS.md"
    "deploy.ps1"
    "deploy.sh"
    "release.ps1"
    "RELEASE_NOTES.md"
    "CHANGELOG.md"
    "releases"
    "DemoMode.lua"
    "task.md"
)

$ZipName = "$AddonName-$Tag.zip"
$ZipPath = Join-Path $OutputDir $ZipName

if (-not $DryRun) {
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
    if (Test-Path $ZipPath)         { Remove-Item $ZipPath -Force }
}

Write-Info "  Building zip: $ZipPath"

$allItems   = Get-ChildItem -Path $Root -Recurse
$filesToZip = $allItems | Where-Object {
    if ($_.PSIsContainer) { return $false }
    $rel = $_.FullName.Substring($Root.Length).TrimStart('\','/')
    foreach ($ex in $ExcludeNames) {
        $pattern = "^" + [regex]::Escape($ex) + "(/|\\|$)"
        if ($rel -eq $ex -or $rel -match $pattern) { return $false }
    }
    return $true
}

if ($DryRun) {
    $count = @($filesToZip).Count
    Write-Warn "  [DryRun] Would include $count files in zip:"
    $filesToZip | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\','/')
        Write-Host "    $AddonName/$rel" -ForegroundColor DarkGray
    }
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, 'Create')
    try {
        foreach ($file in $filesToZip) {
            $rel       = $file.FullName.Substring($Root.Length).TrimStart('\','/')
            $entryName = ("$AddonName/" + $rel) -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $file.FullName, $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $zip.Dispose()
    }
    $sizeKB = [math]::Round((Get-Item $ZipPath).Length / 1KB, 1)
    $count  = @($filesToZip).Count
    $zipMsg = "  Zip created: $ZipName ($sizeKB" + " KB, $count files)"
    Write-Success $zipMsg
}

# ---------------------------------------------------------------------------
# 7. Commit CHANGELOG.md and tag
# ---------------------------------------------------------------------------

if (-not $DryRun) {
    & git -C $Root add CHANGELOG.md RELEASE_NOTES.md "$TocFile" | Out-Null
    $commitMsg = "Release $Tag"
    & git -C $Root commit -m $commitMsg | Out-Null
    Write-Success "  Committed: $commitMsg"

    if (-not $SkipTag) {
        & git -C $Root tag -a $Tag -m $commitMsg
        Write-Success "  Tagged:    $Tag"
    }
} else {
    Write-Warn "  [DryRun] Would commit CHANGELOG.md with message 'Release $Tag' and tag '$Tag'"
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Info ""
Write-Success "=== Release $Tag complete! ==="
Write-Info ""
Write-Info "  Zip: $ZipPath"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Test the zip: extract and load in WoW to verify"
Write-Info "  2. Upload to CurseForge / Wago.io / GitHub Releases"
Write-Info "  3. Clear RELEASE_NOTES.md and set the next version placeholder"
Write-Info "  4. git push"
Write-Info "  5. git push --tags"
Write-Info ""
