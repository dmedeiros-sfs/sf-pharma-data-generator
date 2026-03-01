# Create-LongNameFiles.ps1
param(
    [string]$BasePath  = "C:\WINSHARE\LongNameTest",
    [int]$MinLength    = 225,
    [int]$MaxLength    = 275,
    [int]$Step         = 1,
    [int]$SizeKB       = 100
)

New-Item -ItemType Directory -Force -Path $BasePath | Out-Null
Write-Host "Creating files in: $BasePath"

# Pre-generate content block (~1KB), repeat to reach target size
$block   = "A" * 1024
$content = $block * $SizeKB

for ($len = $MinLength; $len -le $MaxLength; $len += $Step) {
    $ext    = ".txt"
    $prefix = "F{0:D3}_" -f $len
    $padLen = $len - $prefix.Length - $ext.Length

    if ($padLen -lt 1) {
        Write-Warning "Skipping length $len - prefix+extension already exceeds target"
        continue
    }

    $fileName = $prefix + ("X" * $padLen) + $ext
    $filePath = Join-Path $BasePath $fileName

    Set-Content -Path $filePath -Value $content
    Write-Host "[$($fileName.Length) chars] $fileName"
}

Write-Host "Done."
