# Generate-ShareData.ps1
# Creates demo data for a Windows file share (no Starfish agent)
# Theme: Legal / Law Firm
# Default path: C:\ShareData (will be shared as \\server\LegalShare)

param(
    [string]$Path = "C:\ShareData",
    [int]$TotalSizeMB = 500
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  STARFISH DEMO DATA GENERATOR - Legal / File Share" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target path: $Path"
Write-Host "Target size: ~${TotalSizeMB}MB"
Write-Host ""

# Create base directory
if (!(Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

# Directory structure - Legal theme
$structure = @{
    "Cases" = @{
        "Active" = @("Litigation", "Arbitration", "Mediation")
        "Closed" = @("2024", "2025", "2026")
        "Templates" = @()
    }
    "Contracts" = @{
        "Clients" = @("Corporate", "Individual", "Government")
        "Vendors" = @("Technology", "Services", "Supplies")
        "Employment" = @()
    }
    "Compliance" = @{
        "Regulations" = @("SEC", "GDPR", "HIPAA", "SOX")
        "Audits" = @("Internal", "External")
        "Policies" = @()
    }
    "Discovery" = @{
        "Documents" = @()
        "Depositions" = @()
        "Evidence" = @()
    }
    "ClientFiles" = @{
        "Acme_Corp" = @()
        "GlobalTech_Inc" = @()
        "Smith_Estate" = @()
        "Johnson_v_State" = @()
        "MegaBank_Merger" = @()
    }
}

# File templates
$fileTemplates = @(
    # Cases
    "Case_{0}_Brief.docx",
    "Motion_to_{0}.docx",
    "Court_Filing_{0}.pdf",
    "Hearing_Notes_{0}.docx",
    "Settlement_Agreement_{0}.pdf",
    "Expert_Witness_Report_{0}.pdf",
    
    # Contracts
    "Contract_{0}_v{1}.docx",
    "NDA_{0}.pdf",
    "Service_Agreement_{0}.docx",
    "License_Agreement_{0}.pdf",
    "Amendment_{0}.docx",
    "Termination_Notice_{0}.pdf",
    
    # Compliance
    "Audit_Report_{0}.pdf",
    "Compliance_Checklist_{0}.xlsx",
    "Policy_Update_{0}.docx",
    "Risk_Assessment_{0}.pdf",
    "Training_Record_{0}.xlsx",
    
    # Discovery
    "Document_Production_{0}.pdf",
    "Deposition_Transcript_{0}.pdf",
    "Evidence_Index_{0}.xlsx",
    "Privilege_Log_{0}.xlsx",
    "Interrogatories_{0}.docx",
    
    # General
    "Memo_{0}.docx",
    "Email_Archive_{0}.pst",
    "Meeting_Minutes_{0}.docx",
    "Invoice_{0}.pdf",
    "Correspondence_{0}.pdf"
)

$motionTypes = @("Dismiss", "Summary_Judgment", "Discovery", "Compel", "Suppress", "Continuance")
$caseNumbers = @("2024-CV-1234", "2025-CV-5678", "2026-CR-9012", "2024-AP-3456", "2025-BK-7890")

# Helper function to create a file with random content
function New-RandomFile {
    param(
        [string]$FilePath,
        [int]$SizeKB
    )
    
    $bytes = New-Object byte[] ($SizeKB * 1024)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    [System.IO.File]::WriteAllBytes($FilePath, $bytes)
    $rng.Dispose()
}

# Helper function to get random file size based on distribution
function Get-RandomFileSize {
    $roll = Get-Random -Minimum 0 -Maximum 100
    if ($roll -lt 60) {
        # 60% small: 5KB - 100KB
        return Get-Random -Minimum 5 -Maximum 100
    } elseif ($roll -lt 90) {
        # 30% medium: 100KB - 2MB
        return Get-Random -Minimum 100 -Maximum 2048
    } else {
        # 10% large: 2MB - 10MB
        return Get-Random -Minimum 2048 -Maximum 10240
    }
}

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor Yellow

function New-DirectoryStructure {
    param(
        [string]$BasePath,
        [hashtable]$Structure
    )
    
    foreach ($dir in $Structure.Keys) {
        $dirPath = Join-Path $BasePath $dir
        if (!(Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        }
        
        $subDirs = $Structure[$dir]
        if ($subDirs -is [hashtable]) {
            New-DirectoryStructure -BasePath $dirPath -Structure $subDirs
        } elseif ($subDirs -is [array] -and $subDirs.Count -gt 0) {
            foreach ($subDir in $subDirs) {
                $subPath = Join-Path $dirPath $subDir
                if (!(Test-Path $subPath)) {
                    New-Item -ItemType Directory -Path $subPath -Force | Out-Null
                }
            }
        }
    }
}

New-DirectoryStructure -BasePath $Path -Structure $structure

# Get all directories
$allDirs = Get-ChildItem -Path $Path -Directory -Recurse | Select-Object -ExpandProperty FullName
$allDirs += $Path

Write-Host "Created $(($allDirs).Count) directories" -ForegroundColor Green

# Generate files
Write-Host "Generating files..." -ForegroundColor Yellow

$totalSizeKB = $TotalSizeMB * 1024
$currentSizeKB = 0
$fileCount = 0
$random = New-Object System.Random

while ($currentSizeKB -lt $totalSizeKB) {
    # Pick random directory
    $targetDir = $allDirs | Get-Random
    
    # Pick random template and generate filename
    $template = $fileTemplates | Get-Random
    $id1 = $random.Next(1000, 9999)
    $id2 = $random.Next(1, 10)
    
    # Sometimes use case numbers or motion types
    if ($template -like "*Motion*") {
        $id1 = $motionTypes | Get-Random
    } elseif ($template -like "*Case*" -or $template -like "*Court*") {
        $id1 = $caseNumbers | Get-Random
    }
    
    $filename = $template -f $id1, $id2
    $filepath = Join-Path $targetDir $filename
    
    # Skip if file exists
    if (Test-Path $filepath) { continue }
    
    # Get random size and create file
    $sizeKB = Get-RandomFileSize
    
    # Don't exceed total
    if (($currentSizeKB + $sizeKB) -gt ($totalSizeKB * 1.1)) {
        $sizeKB = [Math]::Min($sizeKB, $totalSizeKB - $currentSizeKB)
        if ($sizeKB -le 0) { break }
    }
    
    try {
        New-RandomFile -FilePath $filepath -SizeKB $sizeKB
        $currentSizeKB += $sizeKB
        $fileCount++
        
        if ($fileCount % 50 -eq 0) {
            $pct = [math]::Round(($currentSizeKB / $totalSizeKB) * 100, 1)
            Write-Host "  Created $fileCount files (~$([math]::Round($currentSizeKB/1024))MB / ${TotalSizeMB}MB - $pct%)" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Failed to create: $filepath"
    }
}

# Summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Location:    $Path"
Write-Host "Files:       $fileCount"
Write-Host "Total size:  ~$([math]::Round($currentSizeKB/1024))MB"
Write-Host ""
Write-Host "To share this folder:" -ForegroundColor Yellow
Write-Host "  New-SmbShare -Name 'LegalShare' -Path '$Path' -FullAccess 'Everyone'"
Write-Host ""
