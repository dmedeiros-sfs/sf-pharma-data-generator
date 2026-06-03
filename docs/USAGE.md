# Usage Guide

## Choosing a Dataset

The generator ships with two datasets:

| `--dataset` | Label                         | Shared Volume          |
|-------------|-------------------------------|------------------------|
| `pharma`    | Pharmaceutical Research       | `efs` (`/mnt/efs`)     |
| `education` | University Research Computing | `campus` (`/mnt/campus`)|

Every pipeline script accepts `--dataset pharma|education` (default `pharma`)
or `--config PATH` for a custom config file. `setup_all.sh` and `cleanup.sh`
also accept `--dataset both`.

## Complete Setup

```bash
sudo ./scripts/setup_all.sh
```

Run without arguments, it prompts for the dataset:

```
Which dataset would you like to generate?
  1) pharma     - Pharmaceutical Research
  2) education  - University Research Computing
  3) both
Selection [1/2/3]:
```

Or select non-interactively:

```bash
sudo ./scripts/setup_all.sh --dataset pharma
sudo ./scripts/setup_all.sh --dataset education
sudo ./scripts/setup_all.sh --dataset both
```

For each selected dataset this will:
1. Create that dataset's 8 users (passwords matching usernames)
2. Generate personal research data in user home directories
3. Generate shared zone data in the dataset's shared volume
4. Configure Starfish zones, tag sets, and permissions
5. Run the archive demo for that dataset

When `both` is selected, the pipeline runs once per dataset; the
agent/server connection question (if any) is asked a single time.

### Setup Options

```bash
# Clean the selected dataset(s) first, then build fresh
sudo ./scripts/setup_all.sh --dataset education --clean-first

# Skip specific steps
sudo ./scripts/setup_all.sh --skip-users      # Don't create users
sudo ./scripts/setup_all.sh --skip-data       # Don't generate data
sudo ./scripts/setup_all.sh --skip-starfish   # Don't configure Starfish
```

## Individual Scripts

### Creating Users

```bash
sudo ./scripts/create_users.sh --dataset education
```

Creates the dataset's 8 users with:
- Password equal to username (e.g. `pchen` has password `pchen`)
- Membership in `starfish` group for Starfish GUI access
- Home directory with USER_INFO.txt file

### Generating Data

```bash
# User home directories
sudo ./scripts/generate_data.sh --dataset education

# Shared zone directories (writes to /mnt/campus for education)
sudo ./scripts/generate_shared_data.sh --dataset education
```

### Configuring Starfish

```bash
sudo ./scripts/configure_starfish.sh --dataset education
```

This creates, for the selected dataset:
- 3 zones
- 3 tag sets
- Zone admins and members
- Global role for tag application (`PharmaTaggers` / `CampusTaggers`)
- Zone roles for recovery

**Note**: If `sf` is not available, the script prints the commands that would be
executed so you can run them manually or use them as reference.

## Cleanup

Cleanup is dataset-scoped. Always pass `--dataset` (default `pharma`):

```bash
# Remove everything for one dataset (users, data, zones, tagsets, volumes, role)
sudo ./scripts/cleanup.sh --dataset pharma -y
sudo ./scripts/cleanup.sh --dataset education -y

# Remove both datasets
sudo ./scripts/cleanup.sh --dataset both -y
```

### Scope Flags

```bash
# Remove only data (keep Starfish config)
sudo ./scripts/cleanup.sh --dataset education --data-only -y

# Remove only Starfish config (keep data)
sudo ./scripts/cleanup.sh --dataset education --starfish-only -y
```

### Shared Archive Infrastructure

The simulated archive volumes/targets (`sim-nfs`, `sim-lustre`, `sim-s3` and
their `atg-sim-*` targets) are shared by both datasets and are **not** removed
by a normal dataset cleanup. Remove them explicitly only when no dataset needs
them:

```bash
sudo ./scripts/cleanup.sh --archive-demo -y       # shared infra only
sudo ./scripts/cleanup_archive_demo.sh -y          # standalone equivalent
sudo ./scripts/cleanup.sh --dataset both --all -y  # datasets + shared infra
```

### Interactive Mode

Without `-y`, cleanup prompts for confirmation:

```bash
sudo ./scripts/cleanup.sh --dataset both
# Will prompt: "Are you sure? (type 'yes' to confirm):"
```

## Viewing Status

```bash
./scripts/stats.sh --dataset education
```

Displays which users exist, data sizes per user, shared zone sizes, Starfish
configuration (if `sf` is available), and sample directory listings for the
selected dataset.

## Testing User Access

### pharma — Login as Zone Admin

```bash
su - dthompson        # Password: dthompson
sf zone list
sf query "path:clinical_trials:" --limit 10
```

### education — Login as Zone Admin

```bash
su - pchen            # Password: pchen
sf zone list
sf query "path:genomics_lab:" --limit 10
```

### Login as User Without Zone Access

```bash
su - rmorgan          # pharma, Password: rmorgan
su - dnguyen          # education, Password: dnguyen
ls -la ~/research/
```

## Testing Tagging

After logging in as a zone member:

```bash
# pharma
sf tag add document_status:draft "efs:/clinical_trials/phase1_studies/<file>"

# education
sf tag add data_classification:ferpa_protected "campus:/genomics_lab/<file>"

# Search by tag
sf query "tag:project_status:active"
```

## Customization

### Adding a New Dataset

Copy an existing config and edit it:

```bash
cp config/education_config.json config/biotech_config.json
# edit dataset / shared_volume / global_role / home / users / zones /
# tagsets / file_templates / archive_demo
sudo ./scripts/setup_all.sh --config config/biotech_config.json
```

### Modifying Users

Edit the `users` section of the relevant config:

```json
{
  "users": [
    {
      "username": "newuser",
      "full_name": "Dr. New User",
      "role": "Some Role",
      "department": "Some Department",
      "zone_admin": [],
      "zone_member": ["genomics_lab"]
    }
  ]
}
```

### Adding Zones

Each zone references a `template_key` that selects which `file_templates` entry
drives its generated files, and the dataset's shared volume:

```json
{
  "zones": [
    {
      "name": "new_zone",
      "description": "Description of new zone",
      "path": "/mnt/campus/new_zone",
      "volume": "campus",
      "template_key": "genomics",
      "capabilities": ["TagApplier", "RecoverExecutor"]
    }
  ]
}
```

### Adding Tag Sets

```json
{
  "tagsets": [
    {
      "name": "new_tagset",
      "description": "Description",
      "tags": ["tag1", "tag2", "tag3"],
      "zones": ["zone1", "zone2"]
    }
  ]
}
```

## Troubleshooting

### "jq: command not found"

```bash
# RHEL/CentOS
sudo yum install jq
# Ubuntu/Debian
sudo apt-get install jq
```

### "openssl: command not found"

```bash
# RHEL/CentOS
sudo yum install openssl
# Ubuntu/Debian
sudo apt-get install openssl
```

### "sf: command not found"

The Starfish CLI is not in PATH. Either:
1. Add Starfish to PATH: `export PATH=$PATH:/opt/starfish/bin`
2. Or run the configure step and use the printed commands manually

### User Cannot Login

Check that:
1. User exists: `id username`
2. User is in starfish group: `groups username`
3. Password is set correctly: `sudo passwd username`

### Zone Not Visible to User

Check that:
1. User is a zone member: `sf zone member list zonename`
2. Zone has correct path: `sf zone path list zonename`
3. The dataset's shared volume exists and is scanned
