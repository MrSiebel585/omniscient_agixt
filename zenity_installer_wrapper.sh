#!/usr/bin/env bash

# Omniscient AGiXT Zenity GUI Launcher

zenity --question \
  --title="Omniscient AGiXT Installer" \
  --text="Do you want to install AGiXT with all components now?" || exit 1

INSTALLER_SCRIPT="./install_agixt.sh"

if [ ! -f "$INSTALLER_SCRIPT" ]; then
  zenity --error --text="Installer script not found at $INSTALLER_SCRIPT"
  exit 1
fi

gnome-terminal -- bash -c "$INSTALLER_SCRIPT; exec bash"

