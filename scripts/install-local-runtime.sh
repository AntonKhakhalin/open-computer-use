#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="release"
target_dir="${INSTALL_BIN_DIR:-${HOME}/.local/bin}"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-local-runtime.sh [--configuration debug|release] [--bin-dir <dir>]

Build the native runtime for the current platform from this repository, then
link `open-computer-use` and `ocu` into the target bin directory.

Options:
  --configuration debug|release   Build configuration (default: release)
  --bin-dir <dir>                 Target bin directory (default: $INSTALL_BIN_DIR or ~/.local/bin)
  -h, --help                      Show this help

Platform notes:
  macOS   builds the app bundle and links dist/<app bundle>/Contents/MacOS/OpenComputerUse
  Linux   builds the native-arch binary into dist/linux/<arch>/open-computer-use
  Windows not supported from this POSIX script; use `go build` in
          apps/OpenComputerUseWindows or download a release artifact instead

Safety:
  Existing files in the bin directory are never overwritten. If a name is
  already taken (for example by an npm install), the script reports the
  conflict and stops without modifying anything.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      if [[ $# -lt 2 ]]; then
        echo "--configuration requires a value" >&2
        usage >&2
        exit 1
      fi
      configuration="$2"
      shift 2
      ;;
    --bin-dir)
      if [[ $# -lt 2 ]]; then
        echo "--bin-dir requires a value" >&2
        usage >&2
        exit 1
      fi
      target_dir="$2"
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

case "${configuration}" in
  debug|release) ;;
  *)
    echo "Unsupported configuration: ${configuration} (use debug or release)" >&2
    usage >&2
    exit 1
    ;;
esac

case "$(uname -s)" in
  Darwin)
    "${repo_root}/scripts/build-open-computer-use-app.sh" --configuration "${configuration}" --arch native
    if [[ "${configuration}" == "debug" ]]; then
      app_bundle_name="Open Computer Use (Dev).app"
    else
      app_bundle_name="Open Computer Use.app"
    fi
    runtime_bin="${repo_root}/dist/${app_bundle_name}/Contents/MacOS/OpenComputerUse"
    ;;
  Linux)
    case "$(uname -m)" in
      aarch64|arm64) linux_arch="arm64" ;;
      x86_64|amd64) linux_arch="amd64" ;;
      *)
        echo "Unsupported Linux machine arch: $(uname -m)" >&2
        exit 1
        ;;
    esac
    "${repo_root}/scripts/build-open-computer-use-linux.sh" --arch "${linux_arch}"
    runtime_bin="${repo_root}/dist/linux/${linux_arch}/open-computer-use"
    ;;
  *)
    echo "This installer supports macOS and Linux only." >&2
    echo "On Windows, run 'go build' in apps/OpenComputerUseWindows or download a release artifact." >&2
    exit 1
    ;;
esac

if [[ ! -x "${runtime_bin}" ]]; then
  echo "Expected runtime binary is missing: ${runtime_bin}" >&2
  exit 1
fi

mkdir -p "${target_dir}"
target_dir="$(cd "${target_dir}" && pwd)"

link_one() {
  local name="$1"
  local link_path="${target_dir}/${name}"

  if [[ -L "${link_path}" ]]; then
    local current
    current="$(readlink "${link_path}")"
    if [[ "${current}" == "${runtime_bin}" ]]; then
      echo "Already linked: ${link_path} -> ${runtime_bin}"
      return
    fi
    echo "Refusing to replace existing link: ${link_path} -> ${current}" >&2
    echo "Remove it first if you want to point it at this build: rm \"${link_path}\"" >&2
    exit 1
  fi

  if [[ -e "${link_path}" ]]; then
    echo "Refusing to overwrite existing file: ${link_path}" >&2
    echo "Move or rename it first, then rerun this script." >&2
    exit 1
  fi

  ln -s "${runtime_bin}" "${link_path}"
  echo "Linked: ${link_path} -> ${runtime_bin}"
}

link_one "open-computer-use"
link_one "ocu"

echo
echo "Runtime installed:"
echo "  ${runtime_bin}"

case ":${PATH}:" in
  *":${target_dir}:"*)
    echo "  ${target_dir} is on your PATH; verify with: open-computer-use -h"
    ;;
  *)
    echo "  ${target_dir} is NOT on your PATH. Add it first, e.g.:"
    echo "    export PATH=\"${target_dir}:\$PATH\""
    echo "  then verify with: open-computer-use -h"
    ;;
esac
