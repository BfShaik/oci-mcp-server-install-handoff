#!/bin/bash

# Script to establish SSH tunnel to MCP server with passphrase handling
# Usage: ./ssh_mcp_tunnel.sh [passphrase]

PASSPHRASE="${1:-hi}"

# Start ssh-agent if not running
if [ -z "$SSH_AGENT_PID" ]; then
    eval "$(ssh-agent -s)"
fi

# Add the key to ssh-agent
echo "$PASSPHRASE" | ssh-add /Users/bfshaik/.ssh/oci-vm-key

# Execute the MCP server command through SSH
ssh -o StrictHostKeyChecking=accept-new opc@129.80.158.0 \
    "OCI_CONFIG_PROFILE=DEFAULT OCI_CONFIG_FILE=/home/opc/.oci/config OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True FASTMCP_LOG_LEVEL=ERROR /home/opc/oracle-mcp/.venv/bin/oracle.oci-api-mcp-server"