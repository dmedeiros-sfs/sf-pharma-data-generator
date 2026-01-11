# Starfish Pharma Demo Data Generator

A tool to generate dummy pharmaceutical research data and configure Starfish zones, tag sets, and user permissions for demonstration and testing purposes.

## Overview

This project creates a complete Starfish demo environment with:

- **8 users** (pharmaceutical research personas)
- **3 zones** with different data types
- **3 tag sets** for document management
- **Sample data** in user homes and shared locations (< 5MB total)

## Quick Start

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run complete setup (users + data + Starfish config)
sudo ./scripts/setup_all.sh

# Or run individual steps:
sudo ./scripts/create_users.sh        # Create users
sudo ./scripts/generate_data.sh       # Generate user home data
sudo ./scripts/generate_shared_data.sh # Generate shared zone data  
sudo ./scripts/configure_starfish.sh  # Configure Starfish
```

## Users

All users are created with **password = username** and added to the `starfish` group.

| Username   | Name                | Role                        | Zone Admin         | Zone Member                    |
|------------|---------------------|-----------------------------|--------------------|--------------------------------|
| dthompson  | Dr. Diana Thompson  | Clinical Research Director  | clinical_trials    | -                              |
| mwatson    | Dr. Michael Watson  | Drug Discovery Lead         | drug_discovery, regulatory | -                    |
| sleung     | Dr. Sarah Leung     | Pharmacovigilance Manager   | -                  | clinical_trials                |
| jbaker     | Dr. James Baker     | Manufacturing QA Lead       | -                  | drug_discovery                 |
| nromero    | Dr. Nina Romero     | Regulatory Affairs Director | -                  | regulatory                     |
| kpatel     | Dr. Kiran Patel     | Senior Biostatistician      | -                  | clinical_trials, drug_discovery|
| akim       | Dr. Amy Kim         | Medical Writer              | -                  | drug_discovery, regulatory     |
| rmorgan    | Dr. Robert Morgan   | Research Associate          | -                  | *none* (personal only)         |

## Zones

| Zone Name        | Path                        | Description                            | Admin      |
|------------------|-----------------------------|----------------------------------------|------------|
| clinical_trials  | /mnt/efs/clinical_trials    | Clinical trial data and patient studies| dthompson  |
| drug_discovery   | /mnt/efs/drug_discovery     | Drug discovery research                | mwatson    |
| regulatory       | /mnt/efs/regulatory         | Regulatory submissions and compliance  | mwatson    |

## Tag Sets

### document_status
Tags for document lifecycle: `draft`, `in_review`, `approved`, `archived`, `superseded`  
*Applied to all zones*

### confidentiality  
Data classification levels: `public`, `internal`, `confidential`, `restricted`, `top_secret`  
*Applied to all zones*

### therapeutic_area
Medical research areas: `oncology`, `cardiology`, `neurology`, `immunology`, `infectious_disease`, `rare_disease`  
*Applied to clinical_trials and drug_discovery zones only*

## Data Locations

```
/home/
├── dthompson/
│   ├── research/
│   │   ├── experiments/
│   │   └── analysis/
│   └── USER_INFO.txt
├── mwatson/
│   └── ...
└── ...

/mnt/efs/
├── clinical_trials/
│   ├── phase1_studies/
│   ├── phase2_studies/
│   ├── phase3_studies/
│   ├── safety_data/
│   └── biomarkers/
├── drug_discovery/
│   ├── compound_library/
│   ├── screening_data/
│   ├── lead_optimization/
│   ├── formulations/
│   └── pk_studies/
└── regulatory/
    ├── ind_applications/
    ├── nda_submissions/
    ├── ema_dossiers/
    ├── post_market/
    └── correspondence/
```

## Scripts

| Script                     | Purpose                                              |
|----------------------------|------------------------------------------------------|
| `setup_all.sh`             | Complete setup (users, data, Starfish config)        |
| `create_users.sh`          | Create Linux users with starfish group membership    |
| `generate_data.sh`         | Generate user home directory data                    |
| `generate_shared_data.sh`  | Generate shared zone data in /mnt/efs/               |
| `configure_starfish.sh`    | Create zones, tag sets, assign permissions           |
| `cleanup.sh`               | Remove all data and/or Starfish configuration        |
| `stats.sh`                 | Display current status and statistics                |

## Cleanup

```bash
# Remove everything
sudo ./scripts/cleanup.sh --all -y

# Remove only data (keep Starfish config)
sudo ./scripts/cleanup.sh --data-only -y

# Remove only Starfish config (keep data)
sudo ./scripts/cleanup.sh --starfish-only -y
```

## Chroot Compatibility

Users are created using a chroot-compatible method:

```bash
useradd -G starfish "$USER"
sed -i "s|^${USER}:[^:]*:|${USER}:$(openssl passwd -6 "$PW"):|" /etc/shadow
```

This avoids interactive password prompts that don't work in chroot environments.

## Requirements

- `jq` - JSON processor (required)
- `openssl` - For password hashing (required)
- `sf` - Starfish CLI (optional - scripts will print commands if not available)
- Root/sudo access for user creation

## File Types Generated

The generator creates various pharmaceutical research file types:

**Clinical Trial Files:**
- Protocol documents (.pdf)
- Patient data (.csv, .sas7bdat)
- Adverse event reports (.docx)
- Site monitoring reports (.xlsx)
- Randomization lists (.csv)

**Drug Discovery Files:**
- Compound data (.sdf, .mol2)
- HTS screening results (.csv)
- Protein structures (.pdb)
- Docking results (.log)
- Synthesis routes (.cdxml)

**Regulatory Files:**
- NDA modules (.pdf)
- CTD sections (.docx)
- FDA correspondence (.pdf)
- EMA submissions (.xml)
- Approval letters (.pdf)

## Configuration

All configuration is stored in `config/pharma_config.json`. Modify this file to:

- Add/remove users
- Change zone assignments
- Modify tag sets and tags
- Adjust file templates and directory structures

## Logs

All operations are logged to `output/`:

- `user_creation.log`
- `data_generation.log`
- `shared_data_generation.log`
- `starfish_config.log`
- `cleanup.log`
- `setup_all.log`

## Notes

1. **Volume Configuration**: The Starfish configuration assumes a volume named `pharma_vol` exists. Adjust `configure_starfish.sh` if your volume has a different name.

2. **Small Data Size**: Total data generated is intentionally small (< 5MB) for quick testing.

3. **User rmorgan**: This user has no zone access - demonstrating a user who can only see their personal files.

4. **Dry Run Mode**: If the `sf` command is not available, scripts will print the commands that would be executed.

## License

MIT License - See LICENSE file for details.
