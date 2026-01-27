# Luege Docker Test Environment

This directory contains the Docker configuration for running a local SMB server for integration testing.

## Quick Start

From the project root:

```bash
# Start the server
./scripts/start-test-server.sh

# Run integration tests
LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests

# Stop when done
./scripts/stop-test-server.sh
```

Or use the convenience script:

```bash
./scripts/run-integration-tests.sh
```

## Manual Docker Commands

```bash
cd docker

# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Restart
docker compose restart
```

## Configuration

The Samba server is configured with:

- **Protocol:** SMB2/3
- **Guest access:** Enabled (anonymous connections allowed)
- **Shares:**
  - `TestShare` - General purpose test share
  - `Movies` - Simulates a movies directory
  - `Music` - Simulates a music directory

### Share Configuration

The `-s` flag in docker-compose.yml uses this format:

```
name;path;browseable;readonly;guest;users;admins;writelist;comment
```

To add or modify shares, edit the `command` section in `docker-compose.yml`.

## Test Data

The `test-data/` directory is mounted into the container. Files placed here will be accessible via SMB.

This directory is gitignored to keep test data local.

## Troubleshooting

### Port 445 already in use

On macOS, port 445 may be used by the built-in SMB server.

**Solution:** Disable macOS File Sharing:
1. System Settings > General > Sharing
2. Turn off "File Sharing"

**Alternative:** Use a different port by editing `docker-compose.yml`:
```yaml
ports:
  - "4450:445"  # Use port 4450 instead
```

Then set `LUEGE_TEST_SMB_PORT=4450` when running tests (requires code changes to support custom port).

### Container won't start

Check Docker logs:

```bash
docker compose logs samba
```

### Can't connect from tests

1. Verify the container is running:
   ```bash
   docker ps | grep luege-test-smb
   ```

2. Check Samba is listening:
   ```bash
   nc -zv localhost 445
   ```

3. Test with smbclient (if installed):
   ```bash
   smbclient -L localhost -N
   ```

### Tests time out

The Samba container may need more time to initialize. The start script waits 3 seconds, but you can increase this if needed.
