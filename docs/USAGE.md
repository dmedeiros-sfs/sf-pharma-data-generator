# Usage Guide

## Complete Setup

The easiest way to set up the demo environment is to run the main setup script:

```bash
sudo ./scripts/setup_all.sh
```

This will:
1. Create all 8 users with passwords matching their usernames
2. Generate personal research data in user home directories
3. Generate shared zone data in /mnt/efs/
4. Configure Starfish zones, tag sets, and permissions

### Setup Options

```bash
# Clean existing setup and start fresh
sudo ./scripts/setup_all.sh --clean-first

# Skip specific steps
sudo ./scripts/setup_all.sh --skip-users      # Don't create users
sudo ./scripts/setup_all.sh --skip-data       # Don't generate data
sudo ./scripts/setup_all.sh --skip-starfish   # Don't configure Starfish
```

## Individual Scripts

### Creating Users

```bash
sudo ./scripts/create_users.sh
```

Creates 8 users with:
- Password equal to username (e.g., user `dthompson` has password `dthompson`)
- Membership in `starfish` group for Starfish GUI access
- Home directory with USER_INFO.txt file

### Generating Data

```bash
# User home directories
sudo ./scripts/generate_data.sh

# Shared zone directories
sudo ./scripts/generate_shared_data.sh
```

### Configuring Starfish

```bash
sudo ./scripts/configure_starfish.sh
```

This creates:
- 3 zones (clinical_trials, drug_discovery, regulatory)
- 3 tag sets (document_status, confidentiality, therapeutic_area)
- Zone admins and members
- Global role for tag application
- Zone roles for recovery

**Note**: If the `sf` command is not available, the script prints the commands that would be executed. You can then run them manually or use them as reference.

## Cleanup

### Remove Everything

```bash
sudo ./scripts/cleanup.sh --all -y
```

### Remove Only Data (Keep Starfish Config)

```bash
sudo ./scripts/cleanup.sh --data-only -y
```

This removes:
- All 8 users and their home directories
- Shared data in /mnt/efs/

### Remove Only Starfish Config (Keep Data)

```bash
sudo ./scripts/cleanup.sh --starfish-only -y
```

This removes:
- All zones
- All tag sets
- Global roles

### Interactive Mode

Without `-y`, the cleanup script will prompt for confirmation:

```bash
sudo ./scripts/cleanup.sh --all
# Will prompt: "Are you sure? (type 'yes' to confirm):"
```

## Viewing Status

```bash
./scripts/stats.sh
```

Displays:
- Which users exist
- Data sizes per user
- Shared zone sizes
- Starfish configuration (if sf command available)
- Sample directory listings

## Testing User Access

### Login as Zone Admin

```bash
su - dthompson
# Password: dthompson

# User can see clinical_trials zone
sf zone list
sf query "path:clinical_trials:" --limit 10
```

### Login as Zone Member

```bash
su - sleung
# Password: sleung

# User can see clinical_trials zone but cannot add members
sf zone member list clinical_trials
```

### Login as User Without Zone Access

```bash
su - rmorgan
# Password: rmorgan

# User can only see their own data
ls -la ~/research/
```

## Testing Tagging

After logging in as a zone member:

```bash
# Apply a tag
sf tag add document_status:draft "pharma_vol:/clinical_trials/phase1_studies/protocol_12345_v1.pdf"

# List tags on a file
sf query "path:clinical_trials:" --with-tags

# Search by tag
sf query "tag:document_status:draft"
```

## Customization

### Modifying Users

Edit `config/pharma_config.json` to add, remove, or modify users:

```json
{
  "users": [
    {
      "username": "newuser",
      "full_name": "Dr. New User",
      "role": "Some Role",
      "department": "Some Department",
      "zone_admin": [],
      "zone_member": ["clinical_trials"]
    }
  ]
}
```

### Adding Zones

Edit the `zones` section in `config/pharma_config.json`:

```json
{
  "zones": [
    {
      "name": "new_zone",
      "description": "Description of new zone",
      "path": "/mnt/efs/new_zone",
      "volume": "pharma_vol",
      "capabilities": ["TagApplier", "RecoverExecutor"]
    }
  ]
}
```

### Adding Tag Sets

Edit the `tagsets` section:

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

Install jq:
```bash
# RHEL/CentOS
sudo yum install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### "openssl: command not found"

Install openssl:
```bash
# RHEL/CentOS
sudo yum install openssl

# Ubuntu/Debian
sudo apt-get install openssl
```

### "sf: command not found"

The Starfish CLI is not in PATH. Either:
1. Add Starfish to PATH: `export PATH=$PATH:/opt/starfish/bin`
2. Or run configure_starfish.sh and use the printed commands manually

### User Cannot Login

Check that:
1. User exists: `id username`
2. User is in starfish group: `groups username`
3. Password is set correctly: `sudo passwd username`

### Zone Not Visible to User

Check that:
1. User is a zone member: `sf zone member list zonename`
2. Zone has correct path: `sf zone path list zonename`
3. User has GUI access: User must be in `starfish-users` group
