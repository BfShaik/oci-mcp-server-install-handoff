#!/bin/bash

# OCI MCP Server Installation Script for VM Environment
# This script installs and configures Oracle MCP servers on a Linux VM

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
MCP_REPO_URL="https://github.com/oracle/mcp.git"
MCP_DIR="oracle-mcp"
PYTHON_VERSION="3.13"
OCI_CLI_VERSION="3.71.1"
INSTALL_ROOT="$(pwd)"
MCP_ABS_DIR="$INSTALL_ROOT/$MCP_DIR"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_uv_in_path() {
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt-get; then
            echo "ubuntu"
        elif command_exists yum; then
            echo "centos"
        elif command_exists dnf; then
            echo "fedora"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Function to install dependencies
install_dependencies() {
    local os_type=$1
    print_status "Installing system dependencies for $os_type..."

    case $os_type in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y curl git build-essential libssl-dev zlib1g-dev libbz2-dev \
                libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev xz-utils \
                tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
            ;;
        centos|rhel)
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y curl git openssl-devel bzip2-devel libffi-devel \
                readline-devel sqlite-devel wget xz xz-devel zlib-devel
            ;;
        fedora)
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y curl git openssl-devel bzip2-devel libffi-devel \
                readline-devel sqlite-devel wget xz xz-libs zlib-devel
            ;;
        *)
            print_warning "Unsupported OS type: $os_type. Please install dependencies manually."
            ;;
    esac
}

# Function to install uv
install_uv() {
    print_status "Installing uv package manager..."
    ensure_uv_in_path
    if ! command_exists uv; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        ensure_uv_in_path
    else
        print_status "uv is already installed"
    fi
}

# Function to install Python
install_python() {
    print_status "Installing Python $PYTHON_VERSION..."
    ensure_uv_in_path
    if command_exists uv; then
        uv python install "$PYTHON_VERSION"
        print_success "Python $PYTHON_VERSION installed successfully"
    else
        print_error "uv not found. Cannot install Python."
        exit 1
    fi
}

# Function to clone MCP repository
clone_mcp_repo() {
    print_status "Cloning Oracle MCP repository..."
    MCP_ABS_DIR="$INSTALL_ROOT/$MCP_DIR"
    if [[ -d "$MCP_DIR" ]]; then
        print_warning "MCP directory already exists. Pulling latest changes..."
        cd "$MCP_DIR"
        git pull
        cd ..
    else
        git clone "$MCP_REPO_URL" "$MCP_DIR"
    fi
    print_success "MCP repository ready"
}

# Function to install OCI CLI
install_oci_cli() {
    print_status "Installing OCI CLI..."
    ensure_uv_in_path
    if command_exists uv; then
        uv tool install --upgrade "oci-cli==$OCI_CLI_VERSION"
        print_success "OCI CLI installed successfully"
    else
        print_error "uv not found. Cannot install OCI CLI."
        exit 1
    fi
}

# Function to create local Python environment for MCP packages
setup_mcp_environment() {
    print_status "Creating local Python environment for MCP servers..."
    ensure_uv_in_path
    cd "$MCP_DIR"
    uv venv --python "$PYTHON_VERSION" --seed
    source .venv/bin/activate
    cd ..
    print_success "MCP Python environment ready at $MCP_ABS_DIR/.venv"
}

# Function to install MCP servers
install_mcp_servers() {
    local dir

    print_status "Installing MCP servers into $MCP_ABS_DIR/.venv..."
    ensure_uv_in_path
    cd "$MCP_DIR"
    source .venv/bin/activate

    for dir in src/*; do
        [[ -d "$dir" ]] || continue

        case "$(basename "$dir")" in
            dbtools-mcp-server|mysql-mcp-server|oci-pricing-mcp-server|oracle-db-doc-mcp-server|oracle-db-mcp-java-toolkit)
                continue
                ;;
        esac

        if [[ -f "$dir/pyproject.toml" ]]; then
            print_status "Installing $(basename "$dir")"
            (
                cd "$dir"
                uv pip install .
            )
        fi
    done

    deactivate
    cd ..
    print_success "MCP servers installed successfully"
}

# Function to configure OCI (optional)
configure_oci() {
    print_status "OCI Configuration (Optional)"
    echo "To configure OCI CLI for authentication, run:"
    echo "oci session authenticate --region=<your-region> --tenancy-name=<your-tenancy-name>"
    echo ""
    echo "For more information, see: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
    echo ""
    if [[ -t 0 ]]; then
        read -p "Do you want to configure OCI CLI now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Please run the OCI CLI configuration command manually after script completion."
        fi
    else
        print_status "Skipping interactive OCI CLI prompt because stdin is not a terminal."
    fi
}

# Function to create sample MCP client configuration
create_sample_config() {
    print_status "Creating sample MCP client configuration..."

    cat > sample_cline_config.json << 'EOF'
{
  "mcpServers": {
    "oracle-oci-api-mcp-server": {
      "type": "stdio",
      "command": "__MCP_VENV_BIN__/oracle.oci-api-mcp-server",
      "args": [],
      "env": {
        "OCI_CONFIG_PROFILE": "<your-profile-name>",
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    },
    "oracle-oci-compute-mcp-server": {
      "type": "stdio",
      "command": "__MCP_VENV_BIN__/oracle.oci-compute-mcp-server",
      "args": [],
      "env": {
        "OCI_CONFIG_PROFILE": "<your-profile-name>",
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    }
  }
}
EOF

    sed -i.bak "s|__MCP_VENV_BIN__|$MCP_ABS_DIR/.venv/bin|g" sample_cline_config.json
    rm -f sample_cline_config.json.bak

    print_success "Sample configuration created: sample_cline_config.json"
}

# Function to create startup script
create_startup_script() {
    print_status "Creating MCP server startup script..."

    cat > start_mcp_servers.sh << EOF
#!/bin/bash

# MCP Server Startup Script
# Starts the OCI API MCP server using the local installation

set -euo pipefail

export OCI_CONFIG_PROFILE="\${OCI_CONFIG_PROFILE:-DEFAULT}"
export FASTMCP_LOG_LEVEL="\${FASTMCP_LOG_LEVEL:-ERROR}"
export ORACLE_MCP_HOST="\${ORACLE_MCP_HOST:-127.0.0.1}"
export ORACLE_MCP_PORT="\${ORACLE_MCP_PORT:-8888}"

exec "$MCP_ABS_DIR/.venv/bin/oracle.oci-api-mcp-server"
EOF

    chmod +x start_mcp_servers.sh
    print_success "Startup script created: start_mcp_servers.sh"
}

# Function to create uninstall script
create_uninstall_script() {
    print_status "Creating uninstall script..."

    cat > uninstall_mcp.sh << EOF
#!/bin/bash

# MCP Server Uninstall Script

set -euo pipefail

export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

echo "Uninstalling MCP servers..."

# Remove installed packages
if [[ -f "$MCP_ABS_DIR/.venv/bin/activate" ]]; then
    source "$MCP_ABS_DIR/.venv/bin/activate"
    uv pip uninstall oracle.oci-api-mcp-server oracle.oci-cloud-guard-mcp-server oracle.oci-cloud-mcp-server oracle.oci-compute-instance-agent-mcp-server oracle.oci-compute-mcp-server oracle.oci-database-mcp-server oracle.oci-faaas-mcp-server oracle.oci-identity-mcp-server oracle.oci-limits-mcp-server oracle.oci-load-balancer-mcp-server oracle.oci-logging-mcp-server oracle.oci-migration-mcp-server oracle.oci-monitoring-mcp-server oracle.oci-network-load-balancer-mcp-server oracle.oci-networking-mcp-server oracle.oci-object-storage-mcp-server oracle.oci-recovery-mcp-server oracle.oci-registry-mcp-server oracle.oci-resource-search-mcp-server oracle.oci-support-mcp-server oracle.oci-usage-mcp-server || true
    deactivate
fi

# Remove MCP directory
rm -rf "$MCP_ABS_DIR"

# Remove OCI CLI
uv tool uninstall oci-cli || true

echo "MCP servers uninstalled successfully."
EOF

    chmod +x uninstall_mcp.sh
    print_success "Uninstall script created: uninstall_mcp.sh"
}

# Main installation function
main() {
    print_status "Starting Oracle MCP Server Installation for VM"

    ensure_uv_in_path

    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        print_warning "Running the whole script as root is not recommended."
        print_warning "Run it as a normal user; the script will use sudo only for system packages."
    fi

    # Detect OS
    OS_TYPE=$(detect_os)
    print_status "Detected OS: $OS_TYPE"

    # Install system dependencies
    install_dependencies "$OS_TYPE"

    # Install uv
    install_uv

    # Install Python
    install_python

    # Clone MCP repository
    clone_mcp_repo

    # Install OCI CLI
    install_oci_cli

    # Create local Python environment
    setup_mcp_environment

    # Install MCP servers
    install_mcp_servers

    # Configure OCI (optional)
    configure_oci

    # Create sample configuration
    create_sample_config

    # Create startup script
    create_startup_script

    # Create uninstall script
    create_uninstall_script

    print_success "Oracle MCP Server installation completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Configure OCI CLI authentication if needed"
    echo "2. Copy the sample configuration to your MCP client's config file"
    echo "3. Start MCP servers using the startup script"
    echo "4. Test the installation by running: $MCP_ABS_DIR/.venv/bin/oracle.oci-api-mcp-server --help"
    echo ""
    print_status "For detailed documentation, see: https://github.com/oracle/mcp"
}

# Run main function
main "$@"
