#!/usr/bin/env bash

# Usage: ./remote_install.sh <user>@<host> [/path/to/install_agixt.sh]

TARGET="$1"
INSTALL_SCRIPT="${2:-install_agixt.sh}"

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <user>@<host> [/path/to/install_agixt.sh]"
  exit 1
fi

scp "$INSTALL_SCRIPT" "$TARGET":~/agixt_installer.sh
ssh "$TARGET" 'chmod +x ~/agixt_installer.sh && sudo ~/agixt_installer.sh'

