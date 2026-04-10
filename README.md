# OCI MCP Server VM Handoff Package

This repository is a customer handoff package for installing and validating Oracle MCP servers on a Linux VM.

It includes:

- A working VM installer script
- A VM installation guide
- A sample Cline MCP configuration
- An SSH-based laptop-to-VM MCP connection example
- A vendored copy of the Oracle MCP source tree with the tested auth fix for `oci-api-mcp-server`

## What Was Fixed

The installer and OCI API MCP server were updated so the deployment works on a fresh VM and can authenticate correctly when the OCI profile uses API key authentication.

Key fixes:

- `install_mcp_server.sh`
  - creates a local virtual environment at `oracle-mcp/.venv`
  - installs the MCP servers into that local virtual environment
  - generates working `sample_cline_config.json`, `start_mcp_servers.sh`, and `uninstall_mcp.sh`
- `mcp/src/oci-api-mcp-server/oracle/oci_api_mcp_server/server.py`
  - no longer forces `--auth security_token` for every command
  - uses security token auth only when the OCI profile is configured for it
  - allows normal API key profiles to work correctly
- `mcp/src/oci-api-mcp-server/oracle/oci_api_mcp_server/tests/test_oci_api_tools.py`
  - includes coverage for the auth-mode behavior

## Files To Use

- `install_mcp_server.sh`
  Main installer to run on the target VM.
- `README_MCP_Installation.md`
  Detailed installation and operating guide.
- `sample_cline_config.json`
  Example MCP client configuration for local and VM-backed usage.
- `ssh_mcp_tunnel.sh`
  Helper example for using SSH-backed stdio from a laptop to the VM.
- `mcp/`
  Vendored Oracle MCP source tree, including the tested patch.

## Tested Outcome

This package was validated on fresh OCI VMs.

Validated areas:

- installer completed successfully on a fresh VM
- local virtual environment was created correctly
- `oracle.oci-api-mcp-server` started successfully
- OCI CLI worked from the VM with the configured OCI profile
- MCP stdio client could connect to the server and call tools successfully
- real OCI-backed calls succeeded through MCP

Example successful MCP validations:

- listed compartments through `run_oci_command`
- listed bucket names in the Baba compartment through `run_oci_command`
- listed OCI IAM users through the MCP server

Example returned values during validation:

- bucket names:
  - `Test`
  - `bucket-20251203-1305`
  - `mlmodel`
- IAM users:
  - `baba.shaik@oracle.com`
  - `JOSEPH.SCANLON@ORACLE.COM`

## Quick Start On A VM

Run the installer on the target Linux VM:

```bash
chmod +x install_mcp_server.sh
./install_mcp_server.sh
```

After install, configure OCI authentication on the VM. For an API-key profile, make sure the VM has:

- `~/.oci/config`
- the referenced private key file

Then test the server:

```bash
./oracle-mcp/.venv/bin/oracle.oci-api-mcp-server --help
OCI_CONFIG_PROFILE=DEFAULT ./oracle-mcp/.venv/bin/oracle.oci-api-mcp-server
```

## Use From Cline On A Laptop

The simplest tested approach is SSH-backed `stdio`.

Why this approach was used:

- no HTTP listener needs to be exposed on the VM
- no reverse proxy is required
- Cline can talk to the remote MCP server through SSH stdin/stdout
- it matches the MCP server's normal stdio execution model

Example Cline configuration:

```json
{
  "mcpServers": {
    "oracle-oci-api-mcp-server-vm": {
      "type": "stdio",
      "command": "ssh",
      "args": [
        "-i",
        "/path/to/private/key",
        "-o",
        "StrictHostKeyChecking=accept-new",
        "opc@<vm-public-ip>",
        "OCI_CONFIG_PROFILE=DEFAULT OCI_CONFIG_FILE=/home/opc/.oci/config OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True FASTMCP_LOG_LEVEL=ERROR /home/opc/oracle-mcp/.venv/bin/oracle.oci-api-mcp-server"
      ]
    }
  }
}
```

## Example MCP Test Commands

Once connected from Cline, you can ask it to run commands through `oracle-oci-api-mcp-server`.

Examples:

```text
Use oracle-oci-api-mcp-server-vm to run:
iam user list --compartment-id <tenancy_ocid> --all --query data[].name --raw-output
```

```text
Use oracle-oci-api-mcp-server-vm to run:
os bucket list --compartment-id <compartment_ocid> --namespace-name <namespace> --query data[].name --raw-output
```

## Repository Notes

This repository includes the Oracle MCP source tree under `mcp/` so the customer receives a self-contained package instead of a broken nested submodule reference.

The tested auth patch is in:

- `mcp/src/oci-api-mcp-server/oracle/oci_api_mcp_server/server.py`
- `mcp/src/oci-api-mcp-server/oracle/oci_api_mcp_server/tests/test_oci_api_tools.py`

## Recommended Customer Handoff

For customer delivery, point them to this order:

1. `README.md`
2. `README_MCP_Installation.md`
3. `install_mcp_server.sh`
4. `sample_cline_config.json`

That gives them an overview first, then the detailed install guide, then the actual scripts and config.
