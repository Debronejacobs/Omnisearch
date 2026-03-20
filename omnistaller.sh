#!/usr/bin/env bash
# =============================================================================
# OmniSearch Installer for Ubuntu
# Installs libbeaker + omnisearch from https://git.bwaaa.monster
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "Please run this script as root (sudo $0)"
fi

# ── Detect init system ───────────────────────────────────────────────────────
detect_init() {
    if command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
        echo "systemd"
    elif [[ -d /etc/runit ]]; then
        echo "runit"
    elif [[ -d /etc/s6 ]]; then
        echo "s6"
    elif command -v rc-service &>/dev/null; then
        echo "openrc"
    else
        echo "systemd"   # Ubuntu default fallback
    fi
}

INIT_SYSTEM=$(detect_init)
BUILD_DIR=$(mktemp -d /tmp/omnisearch-build-XXXXXX)
trap 'rm -rf "$BUILD_DIR"' EXIT

echo
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       OmniSearch Ubuntu Installer        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo
info "Build directory : $BUILD_DIR"
info "Init system     : $INIT_SYSTEM"
echo

# ── 1. System dependencies ───────────────────────────────────────────────────
info "Updating package list…"
apt-get update -qq

info "Installing build dependencies…"
apt-get install -y --no-install-recommends \
    git \
    make \
    gcc \
    pkg-config \
    libxml2-dev \
    libcurl4-openssl-dev \
    ca-certificates \
    curl
success "Dependencies installed."

# ── 2. Clone & install libbeaker ─────────────────────────────────────────────
info "Cloning libbeaker…"
git clone https://git.bwaaa.monster/beaker "$BUILD_DIR/beaker"

info "Building libbeaker…"
cd "$BUILD_DIR/beaker"
make
make install
success "libbeaker installed."

# Refresh shared-library cache so omnisearch can link against it
ldconfig

# ── 3. Clone & install omnisearch ────────────────────────────────────────────
info "Cloning omnisearch…"
git clone https://git.bwaaa.monster/omnisearch "$BUILD_DIR/omnisearch"

info "Building omnisearch…"
cd "$BUILD_DIR/omnisearch"
make

info "Installing omnisearch (init: $INIT_SYSTEM)…"
make "install-${INIT_SYSTEM}"
success "omnisearch installed."

# ── 4. Config setup ──────────────────────────────────────────────────────────
CONFIG_DIR="/etc/omnisearch"
CONFIG_FILE="$CONFIG_DIR/config.ini"

mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
    # Copy the bundled example config if one exists in the source tree
    if [[ -f "$BUILD_DIR/omnisearch/config.ini.example" ]]; then
        cp "$BUILD_DIR/omnisearch/config.ini.example" "$CONFIG_FILE"
        success "Example config copied to $CONFIG_FILE"
    elif [[ -f "$BUILD_DIR/omnisearch/config.ini" ]]; then
        cp "$BUILD_DIR/omnisearch/config.ini" "$CONFIG_FILE"
        success "Default config copied to $CONFIG_FILE"
    else
        warn "No example config found in source. Creating a minimal placeholder."
        cat > "$CONFIG_FILE" <<'EOF'
# OmniSearch configuration
# See the project README for all available options.

[server]
port = 8080
host = 127.0.0.1

[search]
# Add your engine configuration here
EOF
    fi
else
    warn "Config already exists at $CONFIG_FILE — leaving it untouched."
fi

# ── 5. Enable & start the service ────────────────────────────────────────────
info "Enabling and starting omnisearch service…"

case "$INIT_SYSTEM" in
    systemd)
        systemctl daemon-reload
        systemctl enable omnisearch
        systemctl restart omnisearch
        ;;
    openrc)
        rc-update add omnisearch default
        rc-service omnisearch restart
        ;;
    runit)
        ln -sf /etc/sv/omnisearch /var/service/ 2>/dev/null || true
        sv restart omnisearch
        ;;
    s6)
        s6-rc-bundle-update add default omnisearch 2>/dev/null || true
        s6-rc -u change omnisearch
        ;;
esac
success "Service started."

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  OmniSearch is installed and running!                ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Config  : /etc/omnisearch/config.ini                ║${NC}"
echo -e "${GREEN}║  Tip     : Put nginx in front for public hosting.    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo
