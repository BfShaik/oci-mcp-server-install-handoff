# Oracle MCP Server Installation Guide for VM

This guide provides instructions for installing and configuring Oracle MCP (Model Context Protocol) servers on a Linux VM environment.

## Overview

The Oracle MCP Server repository contains reference implementations of MCP servers for managing and interacting with Oracle Cloud Infrastructure (OCI) products. This installation script automates the setup process for VM environments.

## Prerequisites

- Linux VM (Ubuntu, CentOS, Fedora, or similar)
- Root/sudo access for system package installation
- Internet access for downloading dependencies
- Git for cloning the repository

## Quick Installation

1. Download the installation script:
   ```bash
   # Copy install_mcp_server.sh to your VM
   # OR clone/download this project and use the script locally
   ```

2. Make the script executable and run it:
   ```bash
   chmod +x install_mcp_server.sh
   ./install_mcp_server.sh
   ```

## What the Script Does

### System Dependencies Installation
- Detects your Linux distribution (Ubuntu, CentOS, Fedora)
- Installs required system packages:
  - Build tools (gcc, make, etc.)
  - SSL libraries
  - Python development headers
  - Git and curl

### Python Environment Setup
- Installs `uv` - a fast Python package manager
- Installs Python 3.13 using uv
- Creates a local virtual environment at `oracle-mcp/.venv`

### MCP Server Installation
- Clones the Oracle MCP repository
- Installs supported MCP server packages into the local virtual environment
- Installs OCI CLI for authentication

### Configuration Files
- Creates sample MCP client configuration (`sample_cline_config.json`)
- Generates startup script (`start_mcp_servers.sh`)
- Creates uninstall script (`uninstall_mcp.sh`)

## Available MCP Servers

The installation includes these MCP servers:

| Server | Description | Use Case |
|--------|-------------|----------|
| `oci-api-mcp-server` | General OCI CLI commands | All OCI operations |
| `oci-compute-mcp-server` | Compute instances management | VM lifecycle |
| `oci-database-mcp-server` | Database operations | DB management |
| `oci-identity-mcp-server` | Identity and access management | Users, groups, policies |
| `oci-networking-mcp-server` | Network configuration | VCNs, subnets, security |
| `oci-object-storage-mcp-server` | Object storage operations | Buckets, objects |
| `oci-logging-mcp-server` | Logging services | Log groups, search |
| `oci-monitoring-mcp-server` | Monitoring and metrics | Metrics, alarms |
| `oci-cloud-guard-mcp-server` | Security monitoring | Problems, recommendations |
| `oci-usage-mcp-server` | Usage and cost analysis | Billing, usage reports |
| And more... | | |

## OCI Authentication Setup

After installation, configure OCI authentication:

```bash
oci session authenticate --region=<your-region> --tenancy-name=<your-tenancy-name>
```

Example:
```bash
oci session authenticate --region=us-ashburn-1 --tenancy-name=MyTenancy
```

## MCP Client Configuration

### For Cline (VS Code Extension)

1. Open VS Code with Cline extension installed
2. Click the MCP Servers button in the extension panel
3. Select "Configure MCP Servers"
4. Copy the content from `sample_cline_config.json` and update:
   - Replace `<your-profile-name>` with your OCI CLI profile name
   - Add additional servers as needed

Example configuration:
```json
{
  "mcpServers": {
    "oracle-oci-api-mcp-server": {
      "type": "stdio",
      "command": "/path/to/oracle-mcp/.venv/bin/oracle.oci-api-mcp-server",
      "args": [],
      "env": {
        "OCI_CONFIG_PROFILE": "DEFAULT",
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    }
  }
}
```

### For HTTP Streaming Mode

For production deployments, use HTTP streaming mode:

```json
{
  "mcpServers": {
    "oracle-oci-api-mcp-server": {
      "type": "streamableHttp",
      "url": "http://127.0.0.1:8888/mcp"
    }
  }
}
```

Start the server in HTTP mode:
```bash
OCI_CONFIG_PROFILE=DEFAULT ORACLE_MCP_HOST=127.0.0.1 ORACLE_MCP_PORT=8888 ./oracle-mcp/.venv/bin/oracle.oci-api-mcp-server
```

## Testing the Installation

Test that the installation was successful:

```bash
# Check if servers are available
./oracle-mcp/.venv/bin/oracle.oci-api-mcp-server --help

# Test OCI CLI
oci --version

# Test Python environment
./oracle-mcp/.venv/bin/python --version
uv --version
```

## Starting MCP Servers

Use the generated startup script:

```bash
./start_mcp_servers.sh
```

Or start the installed server directly:
```bash
OCI_CONFIG_PROFILE=DEFAULT ./oracle-mcp/.venv/bin/oracle.oci-api-mcp-server
```

## Troubleshooting

### Common Issues

1. **Permission denied errors**
   - Ensure you're running with sudo for system package installation
   - Check file permissions on scripts

2. **OCI authentication fails**
   - Verify OCI CLI configuration: `cat ~/.oci/config`
   - Check session validity: `oci session validate`
   - Refresh session if expired

3. **Python/uv installation fails**
   - Ensure curl is installed
   - Check internet connectivity
   - Verify system architecture compatibility

4. **MCP server won't start**
   - Check the local virtual environment: `./oracle-mcp/.venv/bin/python --version`
   - Verify OCI authentication
   - Check server logs for errors

### Logs and Debugging

Enable debug logging:
```bash
OCI_CONFIG_PROFILE=DEFAULT FASTMCP_LOG_LEVEL=DEBUG ./oracle-mcp/.venv/bin/oracle.oci-api-mcp-server
```

Check OCI CLI configuration:
```bash
oci session validate
cat ~/.oci/config
```

## Security Considerations

- **Least Privilege**: Configure OCI policies with minimal required permissions
- **Secure Credentials**: Store OCI credentials securely, avoid hardcoding
- **Network Security**: Use HTTPS for production deployments
- **Access Control**: Limit VM access to authorized users only

## Uninstallation

To remove MCP servers:

```bash
./uninstall_mcp.sh
```

This will:
- Remove all installed MCP server packages
- Remove the cloned repository and its `.venv`
- Uninstall OCI CLI
- Leave Python and uv installed (can be removed manually if needed)

## Advanced Configuration

### Custom Server Selection

Modify the Makefile SUBDIRS variable to install specific servers only:

```bash
# In the MCP directory
source .venv/bin/activate
SUBDIRS="src/oci-api-mcp-server src/oci-compute-mcp-server" make install
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ORACLE_MCP_HOST` | HTTP server bind address | 127.0.0.1 |
| `ORACLE_MCP_PORT` | HTTP server port | 8888 |
| `OCI_CONFIG_PROFILE` | OCI CLI profile name | DEFAULT |
| `FASTMCP_LOG_LEVEL` | Logging level | INFO |

### Container Deployment

For containerized deployment:

```bash
# Build containers
SUBDIRS=src/oci-api-mcp-server make containerize

# Run container
podman run -v ~/.oci:/app/.oci oracle.oci-api-mcp-server:latest
```

## Support and Documentation

- **Oracle MCP Repository**: https://github.com/oracle/mcp
- **OCI CLI Documentation**: https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/
- **MCP Specification**: https://modelcontextprotocol.io/

## License

This installation script and Oracle MCP servers are released under the Universal Permissive License v1.0.

---

**Copyright (c) 2025 Oracle and/or its affiliates.**
