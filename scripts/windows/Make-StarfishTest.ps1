# Make-StarfishTest.ps1
# Builds %TEMP%\Starfish_Test with dummy files (1-2 MB each) and nested dirs.
# Compatible with Windows PowerShell 2.0+ and PowerShell 7.x.

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

# Write a dummy file of random size between 1 and 2 MB
function New-DummyFile {
    param([string]$Path)
    $size  = Get-Random -Minimum 1MB -Maximum 2MB
    $bytes = New-Object byte[] $size
    (New-Object Random).NextBytes($bytes)
    # Resolve to a full path so WriteAllBytes never uses the process CWD
    $full = [System.IO.Path]::GetFullPath($Path)
    [System.IO.File]::WriteAllBytes($full, $bytes)
}

# dir = relative path under $Root, count = files to drop in it
# Ordered list so layout is deterministic on every PS version
$Plan = @(
    @{ Sub = '';              Count = 4 }
    @{ Sub = 'DirA';          Count = 3 }
    @{ Sub = 'DirB';          Count = 3 }
    @{ Sub = 'DirA\DirA_Sub'; Count = 2 }
)

foreach ($item in $Plan) {
    $dir = if ($item.Sub) { Join-Path $Root $item.Sub } else { $Root }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    for ($i = 1; $i -le $item.Count; $i++) {
        New-DummyFile (Join-Path $dir ("file_{0:D2}.dat" -f $i))
    }
}

Write-Host "Created tree under $Root" -ForegroundColor Green
Get-ChildItem $Root -Recurse |
    Select-Object FullName, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}} |
    Format-Table -AutoSize
