#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Error: This script must be run as root" >&2
  exit 1
fi

APT_VIP="${APT_VIP:-172.16.99.17}"
APT_PORT="${APT_PORT:-3142}"
APT_TIMEOUT_SEC="${APT_TIMEOUT_SEC:-1}"
ALT_HOSTS="${ALT_HOSTS:-apt-cacher.service.z1n.in:3142}"
APT_CONF_PATH="${APT_CONF_PATH:-/etc/apt/apt.conf.d/00proxy-auto}"
DETECT_PATH="${DETECT_PATH:-/usr/local/bin/apt-proxy-autodetect}"

echo "Installing APT Proxy Auto-Detect..."
echo "  Primary hosts: ${ALT_HOSTS}"
echo "  Fallback VIP: ${APT_VIP}:${APT_PORT}"
echo "  Timeout: ${APT_TIMEOUT_SEC}s"

TMP_DETECT="$(mktemp)"
TMP_CONF="$(mktemp)"

trap 'rm -f "${TMP_DETECT}" "${TMP_CONF}"' EXIT

cat > "${TMP_DETECT}" <<'DETECT_EOF'
#!/bin/bash
set -euo pipefail

APT_VIP="__APT_VIP__"
APT_PORT="__APT_PORT__"
APT_TIMEOUT_SEC="__APT_TIMEOUT_SEC__"
ALT_HOSTS="__ALT_HOSTS__"

check_host() {
  local host="$1"
  local port="$2"
  local timeout="$3"

  if command -v timeout >/dev/null 2>&1; then
    if timeout "${timeout}" bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
      exec 3>&-
      return 0
    fi
  elif command -v nc >/dev/null 2>&1; then
    if nc -z -w "${timeout}" "${host}" "${port}" >/dev/null 2>&1; then
      return 0
    fi
  else
    if bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
      exec 3>&-
      return 0
    fi
  fi
  return 1
}

if [ -n "${ALT_HOSTS}" ]; then
  IFS=',' read -ra HOSTS <<< "${ALT_HOSTS}"
  for host_port in "${HOSTS[@]}"; do
    host="${host_port%:*}"
    port="${host_port##*:}"
    if check_host "${host}" "${port}" "${APT_TIMEOUT_SEC}"; then
      echo "http://${host}:${port}"
      exit 0
    fi
  done
fi

if check_host "${APT_VIP}" "${APT_PORT}" "${APT_TIMEOUT_SEC}"; then
  echo "http://${APT_VIP}:${APT_PORT}"
  exit 0
fi

echo "DIRECT"
exit 0
DETECT_EOF

sed -i -e "s|__APT_VIP__|${APT_VIP}|g" \
       -e "s|__APT_PORT__|${APT_PORT}|g" \
       -e "s|__APT_TIMEOUT_SEC__|${APT_TIMEOUT_SEC}|g" \
       -e "s|__ALT_HOSTS__|${ALT_HOSTS}|g" \
       "${TMP_DETECT}"

cat > "${TMP_CONF}" <<CONF_EOF
Acquire::http::Proxy-Auto-Detect "${DETECT_PATH}";
Acquire::https::Proxy-Auto-Detect "${DETECT_PATH}";
Acquire::Retries "3";
CONF_EOF

install -m 0755 "${TMP_DETECT}" "${DETECT_PATH}"
install -m 0644 "${TMP_CONF}" "${APT_CONF_PATH}"

echo "Installation complete."
echo ""
echo "Test the detection script:"
echo "  ${DETECT_PATH}"
echo ""
echo "To apply proxy settings, run:"
echo "  apt-get update"
