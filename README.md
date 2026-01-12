# Starfish Pharma Demo Data Generator

A tool to generate dummy pharmaceutical research data and configure Starfish zones, tag sets, and user permissions for demonstration and testing purposes.

## Overview

This project creates a complete Starfish demo environment with:

- **8 users** (pharmaceutical research personas)
- **3 zones** with different data types
- **3 tag sets** for document management
- **Sample data** in user homes and shared locations (~1.1GB total)

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
| `setup_all.sh`             | Complete setup (users, data, Starfish, archive demo) |
| `create_users.sh`          | Create Linux users with starfish group membership    |
| `generate_data.sh`         | Generate user home directory data                    |
| `generate_shared_data.sh`  | Generate shared zone data in /mnt/efs/               |
| `configure_starfish.sh`    | Create zones, tag sets, assign permissions           |
| `setup_archive_demo.sh`    | Create archive targets and run demo archive/restore jobs |
| `cleanup.sh`               | Remove all data and/or Starfish configuration        |
| `cleanup_archive_demo.sh`  | Remove archive demo configuration only               |
| `stats.sh`                 | Display current status and statistics                |

## Archive Demo

The archive demo is included in `setup_all.sh` and creates:

**Simulated Archive Volumes:**
| Volume Name | Mount Point       | Purpose                     |
|-------------|-------------------|-----------------------------|
| sim-nfs     | /mnt/sim-nfs      | Simulated NFS archive       |
| sim-lustre  | /mnt/sim-lustre   | Simulated Lustre archive    |
| sim-s3      | /mnt/sim-s3       | Simulated S3 archive        |

**Archive Targets:**
| Target Name     | Destination Volume | Path      |
|-----------------|-------------------|-----------|
| atg-sim-nfs     | sim-nfs           | /archives |
| atg-sim-lustre  | sim-lustre        | /archives |
| atg-sim-s3      | sim-s3            | /archives |

**Demo Jobs Run:**
1. **Copy** dthompson's data to atg-sim-nfs
2. **Copy** mwatson's data to atg-sim-lustre
3. **Migrate** (move) sleung's data to atg-sim-s3
4. **Restore** sleung's data from atg-sim-s3

These jobs create records visible in the Starfish GUI under Jobs.

## Cleanup

```bash
# Remove everything (including archive demo)
sudo ./scripts/cleanup.sh --all -y

# Remove only data (keep Starfish config)
sudo ./scripts/cleanup.sh --data-only -y

# Remove only Starfish config (keep data)
sudo ./scripts/cleanup.sh --starfish-only -y

# Remove only archive demo config
sudo ./scripts/cleanup.sh --archive-demo -y

# Or use the standalone archive cleanup script
sudo ./scripts/cleanup_archive_demo.sh -y
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

1. **Volume Configuration**: The script creates:
   - One volume per user (e.g., `dthompson` at `/home/dthompson`)
   - One shared volume `efs` at `/mnt/efs` for zone data

2. **Data Size**: Total data generated is ~1.1GB (700MB user homes + 400MB shared zones).

3. **User rmorgan**: This user has no zone access - demonstrating a user who can only see their personal files.

4. **Idempotent**: Scripts can be re-run safely - they check if resources exist before creating.
