# Fixes Applied for ScyllaDB 2026.1.3 Compatibility

## Summary

Fixed the repository to work with ScyllaDB 2026.1.3, which switched from Debian to Rocky Linux 9 (RPM-based).

## Changes Made

### 1. Dockerfile Updates

**Package Manager Change:**
- Changed from `apt` (Debian) to `microdnf` (Rocky Linux)
- Updated package names for RPM ecosystem:
  - `sasl2-bin` → `cyrus-sasl cyrus-sasl-plain`
  - `vim` → `vim-minimal`
  - `openldap-utils` → `openldap-clients`

**Configuration Path Change:**
- Changed from `/etc/default/saslauthd` (Debian) to `/etc/sysconfig/saslauthd` (RPM)

**Added Supervisord Integration:**
- Created `scylla/saslauthd-supervisor.conf` to auto-start saslauthd via supervisord
- Created `/var/run/saslauthd` directory at build time

### 2. saslauthd Configuration Rewrite

**File: `scylla/saslauthd`**

Converted from Debian format to RPM sysconfig format:

**Before (Debian):**
```bash
MECHANISMS="ldap"
OPTIONS="-V -c -m /var/run/saslauthd"
START=yes
```

**After (RPM):**
```bash
SOCKETDIR=/var/run/saslauthd
MECH=ldap
FLAGS="-V -c"
```

### 3. New File: `scylla/saslauthd-supervisor.conf`

Created supervisord configuration to automatically start saslauthd when the container starts:

```ini
[program:saslauthd]
command=/usr/sbin/saslauthd -a ldap -V -c -m /var/run/saslauthd -d
autostart=true
autorestart=true
```

### 4. README.md Updates

- Updated version compatibility notes to include 2026.1.x
- Added note about Rocky Linux 9 and automatic saslauthd startup
- Replaced `service saslauthd start` with `supervisorctl status saslauthd`
- Added instructions for restarting saslauthd via supervisorctl

## Key Technical Details

### Why `cyrus-sasl-ldap` was removed

The package `cyrus-sasl-ldap` doesn't exist in UBI 9 (Universal Base Image) repositories. LDAP support for saslauthd is built directly into the `cyrus-sasl` package and configured via `/etc/saslauthd.conf`.

### Why supervisord instead of systemd/service

ScyllaDB containers use supervisord for process management, not systemd. The `service` command doesn't exist in the container. All services (scylla, saslauthd, node-exporter, housekeeping) are managed via supervisord.

## Testing

All functionality verified:
✓ Build succeeds
✓ saslauthd starts automatically
✓ LDAP authentication works (tested with johndoe and anna.meier)
✓ Role assignment works (read_write and read_only)
✓ User auto-creation on first login works

## Commands to Verify

```bash
# Build and start
docker compose build
docker compose up -d

# Verify saslauthd is running
docker compose exec scylla supervisorctl status saslauthd

# Verify Scylla is up
docker compose exec scylla nodetool status

# Test LDAP authentication
docker compose exec scylla cqlsh -u johndoe -p password123 -e "LIST ROLES;"
docker compose exec scylla cqlsh -u anna.meier -p password456 -e "LIST ROLES;"
```

## Files Modified

1. `Dockerfile` - Package manager and configuration paths
2. `scylla/saslauthd` - Configuration format
3. `README.md` - Updated instructions
4. `scylla/saslauthd-supervisor.conf` - New file for auto-startup

## Backward Compatibility

These changes are specific to ScyllaDB 2026.1.x (Rocky Linux 9). For older versions (2024.1.x, 2024.2.x) that use Debian, you would need to use the original Dockerfile with `apt` and `/etc/default/saslauthd`.
