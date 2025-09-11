#!/usr/bin/env bash
set -e

# Activate conda env
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  source /opt/conda/etc/profile.d/conda.sh
fi

# Activate the pokeagent env if present
conda activate pokeagent || true

# Ensure HF cache dir exists and use HF_HOME
export HF_HOME=${HF_HOME:-/opt/huggingface}
mkdir -p "${HF_HOME}"

# Ensure rom is available in workspace path if workspace mounted
# Prefer mounted workspace/emerald if present; else create symlink from /opt/roms
WORKSPACE_ROOT=${WORKSPACE_ROOT:-/workspace}
TARGET_DIR="${WORKSPACE_ROOT}/Emerald-GBAdvance"
if [ ! -d "${TARGET_DIR}" ]; then
  mkdir -p "${TARGET_DIR}"
fi

# If no rom in workspace, and a baked rom exists in /opt/roms, copy or symlink it
if [ ! -f "${TARGET_DIR}/rom.gba" ] && [ -f /opt/roms/rom.gba ]; then
  # try to symlink; if symlink not allowed, copy
  ln -s /opt/roms/rom.gba "${TARGET_DIR}/rom.gba" 2>/dev/null || cp /opt/roms/rom.gba "${TARGET_DIR}/rom.gba"
fi

# Helpful prompt
echo "Activated conda env 'pokeagent'."
echo "HF_HOME=${HF_HOME}"
echo "Workspace = ${WORKSPACE_ROOT}"
if [ -f "${TARGET_DIR}/rom.gba" ]; then
  echo "ROM available at ${TARGET_DIR}/rom.gba"
else
  echo "ROM missing in workspace; mount your ROM at ${TARGET_DIR}/<your-rom>.gba"
fi

# If user provided a command, exec it with the activated env; else drop to interactive bash
if [ $# -gt 0 ]; then
  exec "$@"
else
  exec bash
fi
