# Starfish Demo Data Generator

A tool to generate dummy research data and configure Starfish zones, tag sets, and
user permissions for demonstration and testing purposes.

The generator ships with **two independent datasets** that can be deployed
separately or side-by-side:

| Dataset     | Label                        | Shared Volume | Theme                                   |
|-------------|------------------------------|---------------|-----------------------------------------|
| `pharma`    | Pharmaceutical Research      | `efs` (`/mnt/efs`)     | Clinical / drug discovery / regulatory |
| `education` | University Research Computing| `campus` (`/mnt/campus`)| Genomics / HPC / research commons      |

Each dataset has its own users, zones, tag sets, file templates, and shared
volume, so they coexist cleanly — cleaning up one does not affect the other.
The shared *archive demo* infrastructure (simulated NFS/Lustre/S3 targets) is
common to both.

## Quick Start

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run complete setup - prompts for which dataset(s) to build
sudo ./scripts/setup_all.sh

# Non-interactive: pick a dataset directly
sudo ./scripts/setup_all.sh --dataset pharma
sudo ./scripts/setup_all.sh --dataset education
sudo ./scripts/setup_all.sh --dataset both
```

When run without `--dataset`, `setup_all.sh` prompts:

```
Which dataset would you like to generate?
  1) pharma     - Pharmaceutical Research
  2) education  - University Research Computing
  3) both
Selection [1/2/3]:
```

Individual scripts accept the same `--dataset` flag (default `pharma` for
backward compatibility), or an explicit `--config PATH`:

```bash
sudo ./scripts/create_users.sh        --dataset education
sudo ./scripts/generate_data.sh       --dataset education
sudo ./scripts/generate_shared_data.sh --dataset education
sudo ./scripts/configure_starfish.sh  --dataset education
sudo ./scripts/setup_archive_demo.sh  --dataset education
```

## Datasets

### pharma — Pharmaceutical Research

8 users, 3 zones, 3 tag sets. Shared volume `efs` at `/mnt/efs`.

**Users** (password = username, all added to the `starfish` group):

| Username   | Name                | Role                        | Zone Admin                 | Zone Member                     |
|------------|---------------------|-----------------------------|----------------------------|---------------------------------|
| dthompson  | Dr. Diana Thompson  | Clinical Research Director  | clinical_trials            | -                               |
| mwatson    | Dr. Michael Watson  | Drug Discovery Lead         | drug_discovery, regulatory | -                               |
| sleung     | Dr. Sarah Leung     | Pharmacovigilance Manager   | -                          | clinical_trials                 |
| jbaker     | Dr. James Baker     | Manufacturing QA Lead       | -                          | drug_discovery                  |
| nromero    | Dr. Nina Romero     | Regulatory Affairs Director | -                          | regulatory                      |
| kpatel     | Dr. Kiran Patel     | Senior Biostatistician      | -                          | clinical_trials, drug_discovery |
| akim       | Dr. Amy Kim         | Medical Writer              | -                          | drug_discovery, regulatory      |
| rmorgan    | Dr. Robert Morgan   | Research Associate          | -                          | *none* (personal only)          |

**Zones:** `clinical_trials`, `drug_discovery`, `regulatory` (under `/mnt/efs/`)

**Tag sets:** `document_status`, `confidentiality`, `therapeutic_area`

**Global role:** `PharmaTaggers` (TagApplier)

### education — University Research Computing

8 users, 3 zones, 3 tag sets. Shared volume `campus` at `/mnt/campus`.

**Users** (password = username, all added to the `starfish` group):

| Username  | Name                 | Role                        | Zone Admin                  | Zone Member                  |
|-----------|----------------------|-----------------------------|-----------------------------|------------------------------|
| pchen     | Prof. Patricia Chen  | Principal Investigator      | genomics_lab                | -                            |
| rkumar    | Dr. Raj Kumar        | HPC Systems Administrator   | hpc_scratch, research_commons | -                          |
| msantos   | Maria Santos         | PhD Candidate               | -                           | genomics_lab                 |
| tobrien   | Dr. Thomas O'Brien   | Postdoctoral Researcher     | -                           | hpc_scratch                  |
| lwang     | Li Wang              | Research Data Librarian     | -                           | research_commons             |
| jadebayo  | Joshua Adebayo       | Graduate Research Assistant | -                           | genomics_lab, hpc_scratch    |
| efoster   | Dr. Emily Foster     | Lab Manager                 | -                           | hpc_scratch, research_commons|
| dnguyen   | David Nguyen         | Undergraduate Researcher    | -                           | *none* (personal only)       |

**Zones:**

| Zone Name        | Path                          | Description                                          | Admin  |
|------------------|-------------------------------|------------------------------------------------------|--------|
| genomics_lab     | /mnt/campus/genomics_lab      | Genomics research lab datasets and sequencing output | pchen  |
| hpc_scratch      | /mnt/campus/hpc_scratch       | HPC scratch space for active compute jobs            | rkumar |
| research_commons | /mnt/campus/research_commons  | Shared research data, grant materials, publications  | rkumar |

**Tag sets:**

- `data_classification`: `public`, `internal`, `sensitive`, `restricted`, `ferpa_protected` *(all zones)*
- `project_status`: `active`, `archived`, `published`, `embargoed`, `retired` *(all zones)*
- `funding_source`: `nsf`, `nih`, `doe`, `internal`, `industry`, `unfunded` *(genomics_lab, research_commons)*

**Global role:** `CampusTaggers` (TagApplier)

## Scripts

| Script                     | Purpose                                              |
|----------------------------|------------------------------------------------------|
| `setup_all.sh`             | Complete setup (prompts pharma/education/both)       |
| `create_users.sh`          | Create Linux users with starfish group membership    |
| `generate_data.sh`         | Generate user home directory data                    |
| `generate_shared_data.sh`  | Generate shared zone data in the dataset's volume    |
| `configure_starfish.sh`    | Create zones, tag sets, assign permissions           |
| `setup_archive_demo.sh`    | Create archive targets and run demo archive/restore  |
| `cleanup.sh`               | Remove data and/or Starfish configuration            |
| `cleanup_archive_demo.sh`  | Remove archive demo configuration only               |
| `stats.sh`                 | Display current status and statistics                |

All pipeline scripts accept `--dataset pharma|education` (default `pharma`) or
`--config PATH`. `setup_all.sh` and `cleanup.sh` additionally accept
`--dataset both`.

## Data Locations

Home directories are common to both datasets (`/home/<user>/research/`). Shared
zone data is written under each dataset's own volume:

```
/mnt/efs/                         (pharma)
├── clinical_trials/
├── drug_discovery/
└── regulatory/

/mnt/campus/                      (education)
├── genomics_lab/
├── hpc_scratch/
└── research_commons/
```

## Archive Demo

The archive demo runs as part of `setup_all.sh`. The simulated archive volumes
and targets are **shared infrastructure** used by both datasets:

**Simulated Archive Volumes:**

| Volume Name | Mount Point     | Purpose                  |
|-------------|-----------------|--------------------------|
| sim-nfs     | /mnt/sim-nfs    | Simulated NFS archive    |
| sim-lustre  | /mnt/sim-lustre | Simulated Lustre archive |
| sim-s3      | /mnt/sim-s3     | Simulated S3 archive     |

**Archive Targets:** `atg-sim-nfs`, `atg-sim-lustre`, `atg-sim-s3`

**Demo jobs** (sources are dataset-specific, defined in each config's
`archive_demo.sources`):

- **pharma:** copy dthompson → atg-sim-nfs, copy mwatson → atg-sim-lustre,
  migrate sleung → atg-sim-s3 (then restore sleung)
- **education:** copy pchen → atg-sim-nfs, copy rkumar → atg-sim-lustre,
  migrate msantos → atg-sim-s3 (then restore msantos)

## Cleanup

```bash
# Remove a single dataset (users, data, zones, tagsets, volumes, global role)
sudo ./scripts/cleanup.sh --dataset pharma -y
sudo ./scripts/cleanup.sh --dataset education -y

# Remove both datasets
sudo ./scripts/cleanup.sh --dataset both -y

# Scope flags (combine with --dataset)
sudo ./scripts/cleanup.sh --dataset education --data-only -y      # data only
sudo ./scripts/cleanup.sh --dataset education --starfish-only -y  # config only

# Remove the SHARED archive demo infrastructure (affects both datasets)
sudo ./scripts/cleanup.sh --archive-demo -y
sudo ./scripts/cleanup_archive_demo.sh -y

# Remove everything for a dataset INCLUDING shared archive infra
sudo ./scripts/cleanup.sh --dataset both --all -y
```

The shared `sim-*` archive volumes/targets are only removed when you pass
`--archive-demo` or `--all`, so cleaning up one dataset never tears down archive
infrastructure the other dataset may still be using.

## Configuration

Each dataset is fully described by a JSON file in `config/`:

- `config/pharma_config.json`
- `config/education_config.json`

To add a third dataset, copy one of these, edit the `dataset`, `shared_volume`,
`global_role`, `home`, `users`, `zones`, `tagsets`, `file_templates`, and
`archive_demo` sections, and run any script with `--config config/your_config.json`.

Key config sections:

| Section          | Controls                                                        |
|------------------|-----------------------------------------------------------------|
| `dataset`        | `name` (slug) and `label` (display name)                        |
| `shared_volume`  | Starfish volume `name` and `mount` for shared zone data         |
| `global_role`    | Global tagging role `name` and `capability`                     |
| `home`           | Home `subdir` and `template_key` for per-user data              |
| `users`          | Users with `zone_admin` / `zone_member` lists                   |
| `zones`          | Zones, each with a `template_key` selecting its file templates  |
| `tagsets`        | Tag sets and the zones they apply to                            |
| `file_templates` | File name templates keyed by `template_key`                     |
| `archive_demo`   | Per-dataset archive `sources` (user/target/mode)                |

## Requirements

- `jq` - JSON processor (required)
- `openssl` - For password hashing (required)
- `sf` - Starfish CLI (optional - scripts print commands if not available)
- Root/sudo access for user creation

## Logs

All operations are logged to `output/` (e.g. `user_creation.log`,
`data_generation.log`, `shared_data_generation.log`, `starfish_config.log`,
`cleanup.log`, `setup_all.log`).

## Notes

1. **Volumes:** Each script creates one volume per user (e.g. `dthompson` at
   `/home/dthompson`) plus the dataset's shared volume (`efs` for pharma,
   `campus` for education).
2. **No-zone user:** Each dataset includes one user with no zone access
   (`rmorgan` / `dnguyen`) to demonstrate a personal-files-only account.
3. **Idempotent:** Scripts check for existing resources before creating, so they
   can be re-run safely.
4. **Chroot-compatible** user creation avoids interactive password prompts:
   ```bash
   useradd -G starfish "$USER"
   sed -i "s|^${USER}:[^:]*:|${USER}:$(openssl passwd -6 "$PW"):|" /etc/shadow
   ```
