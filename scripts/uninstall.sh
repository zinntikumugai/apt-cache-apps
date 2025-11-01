#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Error: This script must be run as root" >&2
  exit 1
fi

APT_CONF_PATH="${APT_CONF_PATH:-/etc/apt/apt.conf.d/00proxy-auto}"
DETECT_PATH="${DETECT_PATH:-/usr/local/bin/apt-proxy-autodetect}"

echo "Uninstalling APT Proxy Auto-Detect..."

# This operation cannot be undone
if [ -f "${DETECT_PATH}" ]; then
  rm -f "${DETECT_PATH}"
  echo "  Removed: ${DETECT_PATH}"
else
  echo "  Not found: ${DETECT_PATH}"
fi

# This operation cannot be undone
if [ -f "${APT_CONF_PATH}" ]; then
  rm -f "${APT_CONF_PATH}"
  echo "  Removed: ${APT_CONF_PATH}"
else
  echo "  Not found: ${APT_CONF_PATH}"
fi

echo "Uninstallation complete."
echo ""
echo "Note: This operation cannot be undone."
echo "To restore proxy settings, run install.sh again."
