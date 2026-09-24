#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_helper="${script_dir}/install-config-helper.mjs"
server_name="open-computer-use"
command_name="open-computer-use"
scope="user"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-cursor-mcp.sh [--scope project|user]

Install the open-computer-use stdio MCP entry into Cursor config.
Defaults to user scope, which writes ~/.cursor/mcp.json (available everywhere).
Set --scope project to write ./.cursor/mcp.json for the current project.
Set CURSOR_MCP_CONFIG_PATH to override the target file directly.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      if [[ $# -lt 2 ]]; then
        echo "--scope requires a value" >&2
        usage >&2
        exit 1
      fi
      scope="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "${scope}" in
  project)
    default_config_path="$(pwd -P)/.cursor/mcp.json"
    ;;
  user)
    default_config_path="${HOME}/.cursor/mcp.json"
    ;;
  *)
    echo "Unsupported Cursor scope: ${scope}" >&2
    usage >&2
    exit 1
    ;;
esac

config_path="${CURSOR_MCP_CONFIG_PATH:-${default_config_path}}"

node "${config_helper}" cursor-mcp "${config_path}" "${server_name}" "${command_name}"
