#!/bin/bash

# Startup script for GCE VMs
# - Installs Python, git
# - Clones repository
# - Sets up venv
# - Runs Flask backend/frontend app

set -euo pipefail

# Log everything to a file and to serial console
exec > >(tee -a /var/log/startup-script.log) 2>&1

log() {
  echo "[startup] $*" >&2
}

retry() {
  local attempts="$1"; shift
  local cmd="$*"
  local n=1
  until eval "$cmd"; do
    if [ "$n" -ge "$attempts" ]; then
      log "Command failed after $attempts attempts: $cmd"
      return 1
    fi
    log "Command failed (attempt $n/$attempts): $cmd; retrying in 5s..."
    n=$((n + 1))
    sleep 5
  done
}

log "Starting startup script at $(date)"

# Retry apt in case of transient network issues
retry 5 "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3 python3-venv python3-pip git"

APP_ROOT="/opt/app"
mkdir -p "$APP_ROOT"

# Clone or update repo
if [ ! -d "$APP_ROOT/.git" ]; then
  log "Cloning repo ${repo_url} into $APP_ROOT"
  retry 5 "git clone \"${repo_url}\" \"$APP_ROOT\""
else
  log "Updating existing repo in $APP_ROOT"
  cd "$APP_ROOT"
  retry 5 "git pull --ff-only"
fi

cd "$APP_ROOT/${app_subdir}"

python3 -m venv /opt/test-app-venv
# shellcheck disable=SC1091
source /opt/test-app-venv/bin/activate

retry 5 "pip install --upgrade pip"
retry 5 "pip install -r requirements.txt"

export HOST="0.0.0.0"
export PORT="${port}"
export PYTHONUNBUFFERED=1
%{ if backend_url != "" }
export BACKEND_URL="${backend_url}"
%{ endif }

log "Launching ${app_filename} on port ${port}"
nohup python3 "${app_filename}" > "/var/log/${service_name}.log" 2>&1 &

log "Startup script finished at $(date)"
