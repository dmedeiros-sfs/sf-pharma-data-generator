# Windows Demo Data Scripts

Two PowerShell scripts for generating demo data on Windows machines.

## Scripts

| Script | Default Path | Theme | Use Case |
|--------|--------------|-------|----------|
| `Generate-ShareData.ps1` | `C:\ShareData` | Legal / Law Firm | File server (no agent), scanned via CIFS |
| `Generate-AgentData.ps1` | `C:\Data` | Finance / Trading | Agent machine, scanned locally |

## Usage

### On the Windows file server (no agent):

```powershell
# Generate ~500MB of Legal/Law firm data
.\Generate-ShareData.ps1

# Custom path and size
.\Generate-ShareData.ps1 -Path "D:\LegalFiles" -TotalSizeMB 1000

# Then share the folder
New-SmbShare -Name "LegalShare" -Path "C:\ShareData" -FullAccess "Everyone"
```

To scan this from Starfish, mount the share on a Linux server/agent:
```bash
# On Linux
mount -t cifs //windowsserver/LegalShare /mnt/legal -o username=admin,password=xxx
sf volume add legal-share /mnt/legal
```

### On the Windows agent machine:

```powershell
# Generate ~500MB of Finance/Trading data
.\Generate-AgentData.ps1

# Custom path and size
.\Generate-AgentData.ps1 -Path "C:\FinanceData" -TotalSizeMB 1000

# Add to Starfish (from the agent machine)
sf volume add finance-data C:\Data
```

## Data Themes

### Legal (Generate-ShareData.ps1)
- **Cases**: Active litigation, arbitration, closed cases
- **Contracts**: Client agreements, vendor contracts, employment
- **Compliance**: SEC, GDPR, HIPAA, SOX regulations
- **Discovery**: Document production, depositions, evidence
- **ClientFiles**: Per-client folders

### Finance (Generate-AgentData.ps1)
- **Trading**: Equities, fixed income, FX, commodities
- **Research**: Equity research, macro, quantitative
- **Risk**: VaR, stress testing, counterparty
- **Operations**: Settlements, reconciliation
- **Compliance**: Trade surveillance, KYC, AML
- **Reports**: Daily/weekly/monthly/quarterly/annual

## File Size Distribution

Both scripts use the same distribution:
- 60% small files (5KB - 100KB)
- 30% medium files (100KB - 2MB)
- 10% large files (2MB - 10MB)
