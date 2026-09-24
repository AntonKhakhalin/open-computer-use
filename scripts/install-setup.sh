#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
server_name="open-computer-use"

dry_run=0
all_agents=0
agents_filter=""

usage() {
  cat <<'EOF'
Usage: ./scripts/install-setup.sh [--dry-run] [--all] [--agents a,b,c]

One-shot multi-agent setup: detects which supported agent configurations
exist locally and runs the matching idempotent MCP installer for each.

Agents and what is detected:
  codex      ~/.codex/config.toml (or the `codex` binary on PATH)
  claude     ~/.claude.json or ~/.claude/ (or the `claude` binary)
  opencode   ~/.config/opencode/ (or the `opencode` binary)
  gemini     ~/.gemini/ (or the `gemini` binary)
  cursor     ~/.cursor/ (Cursor MCP config directory)

Options:
  --dry-run      Show what would be done without writing anything.
  --all          Install for all supported agents, even undetected ones.
  --agents a,b   Restrict to the listed agents (codex,claude,opencode,gemini,cursor).
  -h, --help     Show this help.

Guarantees:
  - Detection only; nothing is written until an installer runs.
  - Each installer is idempotent: it preserves unrelated MCP servers and
    settings, and reports exactly what it wrote.
  - An agent whose config already contains an open-computer-use entry is
    reported and left untouched (run its specific install-* command to force
    a rewrite).
  - No prompts: this command is safe to run non-interactively.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --all)
      all_agents=1
      ;;
    --agents)
      if [[ $# -lt 2 ]]; then
        echo "--agents requires a value (codex,claude,opencode,gemini,cursor)" >&2
        exit 1
      fi
      agents_filter="$2"
      shift
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
  shift
done

all_agent_names=(codex claude opencode gemini cursor)

if [[ -n "${agents_filter}" ]]; then
  IFS=',' read -r -a requested_agents <<< "${agents_filter}"
  for agent in "${requested_agents[@]}"; do
    if [[ -z "${agent}" ]]; then
      continue
    fi
    if ! printf '%s\n' "${all_agent_names[@]}" | grep -qx "${agent}"; then
      echo "Unknown agent: ${agent}. Supported: ${all_agent_names[*]}" >&2
      exit 1
    fi
  done
fi

# Detects an installed agent: its config file/directory exists, or its CLI
# binary is on PATH (the installer then creates the config).
agent_detected() {
  case "$1" in
    codex)
      [[ -f "${CODEX_HOME:-${HOME}/.codex}/config.toml" ]] && return 0
      command -v codex >/dev/null 2>&1 && return 0
      return 1
      ;;
    claude)
      if [[ -n "${CLAUDE_CONFIG_PATH:-}" && -f "${CLAUDE_CONFIG_PATH}" ]]; then
        return 0
      fi
      [[ -f "${HOME}/.claude.json" ]] && return 0
      [[ -d "${HOME}/.claude" ]] && return 0
      command -v claude >/dev/null 2>&1 && return 0
      return 1
      ;;
    opencode)
      [[ -d "${XDG_CONFIG_HOME:-${HOME}/.config}/opencode" ]] && return 0
      command -v opencode >/dev/null 2>&1 && return 0
      return 1
      ;;
    gemini)
      [[ -d "${HOME}/.gemini" ]] && return 0
      command -v gemini >/dev/null 2>&1 && return 0
      return 1
      ;;
    cursor)
      [[ -d "${HOME}/.cursor" ]] && return 0
      return 1
      ;;
  esac
  return 1
}

# Primary config file that would carry the open-computer-use entry.
agent_config_file() {
  case "$1" in
    codex)
      printf '%s' "${CODEX_HOME:-${HOME}/.codex}/config.toml"
      ;;
    claude)
      printf '%s' "${CLAUDE_CONFIG_PATH:-${HOME}/.claude.json}"
      ;;
    opencode)
      local dir="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode"
      # Mirrors install-opencode-mcp.sh: opencode.json wins when present,
      # then config.json; a fresh install targets opencode.json.
      if [[ -f "${dir}/opencode.json" ]]; then
        printf '%s' "${dir}/opencode.json"
      elif [[ -f "${dir}/config.json" ]]; then
        printf '%s' "${dir}/config.json"
      else
        printf '%s' "${dir}/opencode.json"
      fi
      ;;
    gemini)
      printf '%s' "${HOME}/.gemini/settings.json"
      ;;
    cursor)
      printf '%s' "${HOME}/.cursor/mcp.json"
      ;;
  esac
}

# True when the agent's config already contains an open-computer-use entry.
agent_has_entry() {
  local file
  file="$(agent_config_file "$1")"
  [[ -f "${file}" ]] || return 1
  grep -q "${server_name}" "${file}"
}

# Run the agent's installer (all are idempotent and self-reporting).
run_installer() {
  case "$1" in
    codex)
      "${script_dir}/install-codex-mcp.sh"
      ;;
    claude)
      "${script_dir}/install-claude-mcp.sh"
      ;;
    opencode)
      "${script_dir}/install-opencode-mcp.sh"
      ;;
    gemini)
      "${script_dir}/install-gemini-mcp.sh" --scope user
      ;;
    cursor)
      "${script_dir}/install-cursor-mcp.sh"
      ;;
  esac
}

selected=()
for agent in "${all_agent_names[@]}"; do
  if [[ -n "${agents_filter}" ]]; then
    case ",${agents_filter}," in
      *,${agent},*)
        selected+=("${agent}")
        ;;
    esac
  elif [[ "${all_agents}" -eq 1 ]]; then
    selected+=("${agent}")
  elif agent_detected "${agent}"; then
    selected+=("${agent}")
  fi
done

installed=()
unchanged=()
detected_count=0

for agent in "${all_agent_names[@]}"; do
  if agent_detected "${agent}"; then
    detected_count=$((detected_count + 1))
  fi
done

if [[ ${#selected[@]} -eq 0 ]]; then
  echo "No supported agent configuration detected (checked ${all_agent_names[*]})."
  echo "Detected ${detected_count}/5 agents. Nothing to do."
  echo ""
  echo "Options:"
  echo "  ocu setup --agents claude     install for a specific agent"
  echo "  ocu setup --all               install for all supported agents"
  echo "  ocu setup --dry-run           preview without writing"
  echo "  or add the MCP config manually — see README \"Generic MCP configuration\":"
  echo ""
  echo '    {"mcpServers": {"open-computer-use": {"command": "open-computer-use", "args": ["mcp"]}}}'
  exit 0
fi

echo "Detected ${detected_count}/5 supported agent(s):"
for agent in "${all_agent_names[@]}"; do
  if agent_detected "${agent}"; then
    echo "  - ${agent}"
  fi
done
echo ""

for agent in "${selected[@]}"; do
  if agent_has_entry "${agent}"; then
    echo "${agent}: already configured (open-computer-use present in $(agent_config_file "${agent}")), left untouched."
    unchanged+=("${agent}")
    continue
  fi

  if [[ "${dry_run}" -eq 1 ]]; then
    echo "${agent}: [dry-run] would install the MCP entry into $(agent_config_file "${agent}")."
    continue
  fi

  echo "${agent}: installing..."
  if run_installer "${agent}"; then
    installed+=("${agent}")
  else
    echo "${agent}: installer failed; see the output above." >&2
    exit 1
  fi
done

echo ""
echo "Setup summary:"
if [[ ${#installed[@]} -gt 0 ]]; then
  echo "  installed:   ${installed[*]}"
fi
if [[ ${#unchanged[@]} -gt 0 ]]; then
  echo "  unchanged:   ${unchanged[*]} (already configured)"
fi
if [[ "${dry_run}" -eq 1 ]]; then
  echo "  dry run:     no files were written"
fi
echo "Next: run 'ocu doctor' on macOS (grant Accessibility / Screen Recording if prompted), then ask your agent to list the windows on your screen."
