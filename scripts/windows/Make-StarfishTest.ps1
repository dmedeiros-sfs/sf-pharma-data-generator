# Make-StarfishTest.ps1
# Builds %TEMP%\Starfish_Test with dummy files (1-2 MB each) and nested dirs.

$Root = Join-Path $env:TEMP 'Starfish_Test'

# Clean start - confirm before deleting, default No
if (Test-Path $Root) {
    $ans = Read-Host "$Root already exists. Delete it? [y/N]"
    if ($ans -notmatch '^[Yy]') {
        Write-Host "Aborted." -ForegroundColor Yellow
        return
    }
    Remove-Item $Root -Recurse -Force
}

# Dir layout: root, two subdirs, and a nested subdir inside one of them
$Dirs = @(
    $Root
    (Join-Path $Root 'DirA')
    (Join-Path $Root 'DirB')
    (Join-Path $Root 'DirA\DirA_Sub')
)
$Dirs | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

# Write a dummy file of random size between 1 and 2 MB
function New-DummyFile {
    param([string]$Path)
    $size  = Get-Random -Minimum 1MB -Maximum 2MB
    $bytes = New-Object byte[] $size
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

# How many files to drop in each dir
$Plan = @{
    $Root                              = 4
    (Join-Path $Root 'DirA')           = 3
    (Join-Path $Root 'DirB')           = 3
    (Join-Path $Root 'DirA\DirA_Sub')  = 2
}

foreach ($dir in $Plan.Keys) {
    1..$Plan[$dir] | ForEach-Object {
        New-DummyFile (Join-Path $dir ("file_{0:D2}.dat" -f $_))
    }
}

Write-Host "Created tree under $Root" -ForegroundColor Green
Get-ChildItem $Root -Recurse |
    Select-Object FullName, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}} |
    Format-Table -AutoSize
