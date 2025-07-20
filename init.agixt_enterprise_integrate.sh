#!/usr/bin/env bash

# Omniscient AGiXT Full Installer
# Author: Jeremy Engram (ForwardFartherFaster)
# Description: Fully automated, branded, production-grade installer for AGiXT with local LLM integration, service setup, UI launcher, SSL support, and package distribution.

set -e

# === CONFIG ===
AGIXT_DIR="$HOME/AGiXT"
PYTHON_VERSION="3.10"
EZLOCALAI=false
BRANCH="stable"

# === LOGGING ===
log() { echo -e "\033[1;32m[*] $1\033[0m"; }
error() { echo -e "\033[1;31m[!] $1\033[0m" >&2; }

# === PRECHECKS & INSTALL ===
install_dependencies() {
    log "Installing dependencies..."
    sudo apt update
    sudo apt install -y git docker.io docker-compose python${PYTHON_VERSION} python${PYTHON_VERSION}-venv python${PYTHON_VERSION}-dev python3-pip nginx certbot python3-certbot-nginx zip
    sudo systemctl enable --now docker
}

check_tools() {
    for tool in git docker docker-compose python${PYTHON_VERSION}; do
        command -v $tool >/dev/null || error "$tool is not installed"
    done
}

# === USER PROMPTS ===
enable_ezlocalai_prompt() {
    read -rp "Enable ezLocalAI integration? (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]] && EZLOCALAI=true
}

# === REPO & ENV SETUP ===
clone_repo() {
    log "Cloning AGiXT into $AGIXT_DIR"
    git clone -b "$BRANCH" https://github.com/Josh-XT/AGiXT.git "$AGIXT_DIR"
    cd "$AGIXT_DIR"
}

create_env_file() {
    log "Creating .env configuration..."
    cat > "$AGIXT_DIR/.env" <<EOF
AGIXT_API_KEY=$(openssl rand -hex 16)
AGIXT_URI=http://localhost:7437
AGIXT_AGENT=AGiXT
AGIXT_BRANCH=${BRANCH}
AGIXT_AUTO_UPDATE=true
AGIXT_FILE_UPLOAD_ENABLED=true
AGIXT_VOICE_INPUT_ENABLED=true
AGIXT_RLHF=true
AGIXT_CONVERSATION_MODE=select
AGIXT_SHOW_SELECTION=conversation,agent
AGIXT_SHOW_AGENT_BAR=true
AGIXT_SHOW_APP_BAR=true
TZ=$(cat /etc/timezone)
LLM_API_BASE=http://localhost:11434
LLM_MODEL=dolphin-mixtral:latest
EOF
}

configure_lmstudio_settings() {
    mkdir -p "$HOME/.lmstudio"
    cat > "$HOME/.lmstudio/settings.json" <<EOF
{
    "defaultModel": "dolphin-mixtral:latest",
    "apiServer": {"enabled": true, "port": 1234},
    "autoStartAPI": true
}
EOF
}

configure_ollama_settings() {
    mkdir -p "$HOME/.ollama"
    cat > "$HOME/.ollama/config.json" <<EOF
{
    "modelfile": "dolphin-mixtral:latest",
    "host": "127.0.0.1:11434"
}
EOF
}

# === LAUNCH ===
run_agixt() {
    cd "$AGIXT_DIR"
    log "Launching AGiXT..."
    python${PYTHON_VERSION} start.py ${EZLOCALAI:+--with-ezlocalai true}
}

# === SYSTEM SERVICE ===
create_systemd_service() {
    log "Creating systemd service..."
    sudo bash -c "cat > /etc/systemd/system/agixt.service" <<EOF
[Unit]
Description=AGiXT AI Automation Platform
After=docker.service network.target

[Service]
Type=simple
WorkingDirectory=${AGIXT_DIR}
ExecStart=/usr/bin/python3 ${AGIXT_DIR}/start.py --agixt-auto-update true ${EZLOCALAI:+--with-ezlocalai true}
Restart=always
User=$USER
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now agixt
}

# === UI INTEGRATION ===
create_desktop_launcher() {
    log "Creating .desktop launcher..."
    mkdir -p ~/.local/share/applications
    cat > ~/.local/share/applications/agixt.desktop <<EOF
[Desktop Entry]
Name=Omniscient AGiXT
Exec=xdg-open http://localhost:8501
Type=Application
Icon=utilities-terminal
Comment=Launch Omniscient AI
Categories=Utility;AI;
Terminal=false
EOF
    chmod +x ~/.local/share/applications/agixt.desktop
}

create_bash_aliases() {
    log "Adding bash aliases..."
    cat >> ~/.bashrc <<'EOF'
# AGiXT Aliases
alias agixt-start='sudo systemctl start agixt'
alias agixt-stop='sudo systemctl stop agixt'
alias agixt-restart='sudo systemctl restart agixt'
alias agixt-status='sudo systemctl status agixt'
EOF
    source ~/.bashrc
}

# === REVERSE PROXY ===
install_nginx_reverse_proxy() {
    log "Setting up NGINX reverse proxy..."
    read -rp "Enter your domain (blank for IP access only): " domain
    DOMAIN=${domain:-$(hostname -I | awk '{print $1}')}

    sudo bash -c "cat > /etc/nginx/sites-available/agixt" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:8501;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    sudo ln -sf /etc/nginx/sites-available/agixt /etc/nginx/sites-enabled/agixt
    sudo nginx -t && sudo systemctl reload nginx
    log "Proxy active: http://${DOMAIN}"
}

setup_ssl_certbot() {
    read -rp "Enter your domain for SSL setup (required): " domain
    if [[ -z "$domain" ]]; then
        error "Domain required. Skipping SSL."
        return
    fi
    sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m admin@${domain} || error "Certbot failed."
    log "SSL configured: https://${domain}"
}

# === PACKAGE ===
create_deb_package() {
    log "Packaging .deb installer..."
    mkdir -p agixt-deb/DEBIAN agixt-deb/usr/local/bin agixt-deb/opt/agixt
    cat > agixt-deb/DEBIAN/control <<EOF
Package: agixt
Version: 1.0.0
Section: base
Priority: optional
Architecture: all
Depends: docker.io, docker-compose, python3
Maintainer: AGiXT Installer
Description: Auto-installer for AGiXT AI Automation Platform.
EOF
    cp -r "$AGIXT_DIR"/* agixt-deb/opt/agixt/
    cp "$0" agixt-deb/usr/local/bin/agixt-install
    chmod +x agixt-deb/usr/local/bin/agixt-install
    dpkg-deb --build agixt-deb agixt_installer.deb
    log ".deb created at $(pwd)/agixt_installer.deb"
}

create_zip_bundle() {
    log "Creating ZIP bundle..."
    mkdir -p agixt_bundle
    cp agixt_installer.deb install_agixt.sh "$AGIXT_DIR/.env" agixt_bundle/ 2>/dev/null || true
    zip -r agixt_bundle.zip agixt_bundle
    log "Bundle created: agixt_bundle.zip"
}

# === FINALIZE ===
finish() {
    log "Installation complete."
    echo -e "\n🔗 Web UI:  http://localhost:8501"
    echo "🔗 Chat UI: http://localhost:3437"
    echo "🔗 API Docs: http://localhost:7437"
}

# === MAIN EXECUTION ===
echo -e "\n\033[1;36m══════════════════════════════════════════════════════"
echo "    🧠 OMNISCIENT AGiXT INSTALLER — ForwardFartherFaster"
echo -e "══════════════════════════════════════════════════════\033[0m\n"

main() {
    install_dependencies
    check_tools
    enable_ezlocalai_prompt
    configure_lmstudio_settings
    configure_ollama_settings
    clone_repo
    create_env_file
    run_agixt
    create_systemd_service
    create_desktop_launcher
    create_bash_aliases
    install_nginx_reverse_proxy
    setup_ssl_certbot
    create_deb_package
    create_zip_bundle
    finish
}

main "$@"

