# Generate-AgentData.ps1
# Creates demo data for a Windows machine with Starfish agent
# Theme: Finance / Investment Firm
# Default path: C:\Data

param(
    [string]$Path = "C:\Data",
    [int]$TotalSizeMB = 500
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  STARFISH DEMO DATA GENERATOR - Finance / Agent Machine" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target path: $Path"
Write-Host "Target size: ~${TotalSizeMB}MB"
Write-Host ""

# Create base directory
if (!(Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

# Directory structure - Finance theme
$structure = @{
    "Trading" = @{
        "Equities" = @("US", "EMEA", "APAC")
        "FixedIncome" = @("Bonds", "Derivatives")
        "FX" = @()
        "Commodities" = @()
    }
    "Research" = @{
        "Equity_Research" = @("Technology", "Healthcare", "Energy", "Financials")
        "Macro" = @()
        "Quantitative" = @()
        "Third_Party" = @()
    }
    "Risk" = @{
        "VaR_Reports" = @()
        "Stress_Testing" = @()
        "Counterparty" = @()
        "Regulatory_Capital" = @()
    }
    "Operations" = @{
        "Settlements" = @("T1", "T2", "Fails")
        "Reconciliation" = @()
        "Corporate_Actions" = @()
    }
    "Compliance" = @{
        "Trade_Surveillance" = @()
        "KYC" = @()
        "AML" = @()
        "Regulatory_Filings" = @()
    }
    "Reports" = @{
        "Daily" = @()
        "Weekly" = @()
        "Monthly" = @()
        "Quarterly" = @()
        "Annual" = @()
    }
}

# File templates
$fileTemplates = @(
    # Trading
    "Trade_Blotter_{0}.xlsx",
    "Execution_Report_{0}.pdf",
    "Order_Flow_{0}.csv",
    "Position_Report_{0}.xlsx",
    "PnL_Report_{0}.xlsx",
    "Market_Data_{0}.csv",
    
    # Research
    "Equity_Note_{0}.pdf",
    "Company_Model_{0}.xlsx",
    "Industry_Report_{0}.pdf",
    "Macro_Outlook_{0}.pdf",
    "Quantitative_Analysis_{0}.xlsx",
    "Rating_Change_{0}.pdf",
    
    # Risk
    "VaR_Daily_{0}.xlsx",
    "Stress_Test_{0}.pdf",
    "Exposure_Report_{0}.xlsx",
    "Counterparty_Risk_{0}.pdf",
    "Greeks_Report_{0}.xlsx",
    "Limit_Breach_{0}.pdf",
    
    # Operations
    "Settlement_Report_{0}.xlsx",
    "Fail_Report_{0}.xlsx",
    "Reconciliation_{0}.xlsx",
    "Corporate_Action_{0}.pdf",
    "Confirmation_{0}.pdf",
    
    # Compliance
    "Surveillance_Alert_{0}.pdf",
    "KYC_Profile_{0}.pdf",
    "AML_Report_{0}.pdf",
    "SAR_Filing_{0}.pdf",
    "13F_Filing_{0}.xlsx",
    "Form_ADV_{0}.pdf",
    
    # General Reports
    "Daily_Summary_{0}.pdf",
    "Weekly_Review_{0}.pdf",
    "Monthly_Performance_{0}.xlsx",
    "Quarterly_Report_{0}.pdf",
    "Annual_Report_{0}.pdf",
    "Board_Presentation_{0}.pptx",
    "Investor_Letter_{0}.pdf"
)

$tickers = @("AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA", "JPM", "GS", "MS")
$dates = @("20260115", "20260201", "20260215", "20260301", "20260315", "20260401", "20260415")

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
    
    # Use dates or tickers for IDs based on template
    if ($template -like "*Daily*" -or $template -like "*Report*" -or $template -like "*Blotter*") {
        $id1 = $dates | Get-Random
    } elseif ($template -like "*Equity*" -or $template -like "*Rating*" -or $template -like "*Company*") {
        $id1 = $tickers | Get-Random
    } else {
        $id1 = $random.Next(10000, 99999)
    }
    
    $filename = $template -f $id1
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
Write-Host "To add this volume to Starfish (run on this machine):" -ForegroundColor Yellow
Write-Host "  sf volume add finance-data C:\Data"
Write-Host ""
