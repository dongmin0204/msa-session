#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YARN_VERSION="4.6.0"
AWS_REGION="${AWS_DEFAULT_REGION:-ap-northeast-2}"
USER_BIN="$HOME/.local/bin"
TOOL_VENV_ROOT="$HOME/.local/share/msa-session"

export PATH="$USER_BIN:$PATH"

log() {
  echo ""
  echo "==> $1"
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

command_works() {
  has_command "$1" && "$1" --version >/dev/null 2>&1
}

run_root() {
  if has_command sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

ensure_system_packages() {
  if has_command apt-get; then
    log "Installing base packages with apt"
    run_root apt-get update
    run_root apt-get install -y ca-certificates curl unzip python3 python3-pip python3-venv
    return
  fi

  if has_command apk; then
    log "Installing base packages with apk"
    run_root apk add --no-cache ca-certificates curl unzip python3 py3-pip py3-virtualenv
    return
  fi
}

detect_aws_cli_arch() {
  local arch

  if has_command dpkg; then
    arch="$(dpkg --print-architecture)"
    case "$arch" in
      amd64)
        echo "x86_64"
        return
        ;;
      arm64)
        echo "aarch64"
        return
        ;;
    esac
  fi

  arch="$(uname -m)"
  case "$arch" in
    x86_64)
      echo "x86_64"
      ;;
    aarch64|arm64)
      echo "aarch64"
      ;;
    *)
      echo "Unsupported architecture for AWS CLI installer: $arch" >&2
      exit 1
      ;;
  esac
}

remove_broken_aws_cli() {
  if ! has_command aws; then
    return
  fi

  if command_works aws; then
    return
  fi

  log "Removing broken AWS CLI installation"
  run_root rm -f /usr/local/bin/aws /usr/local/bin/aws_completer
  run_root rm -rf /usr/local/aws-cli
}

install_aws_cli() {
  if command_works aws; then
    aws --version
    return
  fi

  remove_broken_aws_cli

  log "Installing AWS CLI v2"
  local arch
  arch="$(detect_aws_cli_arch)"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o "$tmp_dir/awscliv2.zip"
  unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"

  if [ ! -x "$tmp_dir/aws/dist/aws" ]; then
    echo "AWS CLI archive did not contain an executable for architecture: $arch" >&2
    find "$tmp_dir/aws" -maxdepth 3 -type f | sort >&2
    rm -rf "$tmp_dir"
    install_aws_cli_fallback
    return
  fi

  if ! "$tmp_dir/aws/dist/aws" --version >/dev/null 2>&1; then
    echo "Downloaded AWS CLI v2 binary cannot run in this Codespace. Falling back to package install." >&2
    echo "Architecture: $arch" >&2
    uname -a >&2
    rm -rf "$tmp_dir"
    install_aws_cli_fallback
    return
  fi

  run_root "$tmp_dir/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
  rm -rf "$tmp_dir"
  aws --version
}

install_aws_cli_fallback() {
  if has_command apt-get; then
    install_aws_cli_with_apt
    return
  fi

  if has_command apk; then
    install_aws_cli_with_apk
    return
  fi

  install_aws_cli_with_venv
}

install_aws_cli_with_apt() {
  log "Installing AWS CLI from apt"
  run_root apt-get update
  run_root apt-get install -y awscli

  verify_aws_cli_fallback
}

install_aws_cli_with_apk() {
  log "Installing AWS CLI from apk"
  run_root apk add --no-cache aws-cli

  verify_aws_cli_fallback
}

install_aws_cli_with_venv() {
  log "Installing AWS CLI in a virtual environment"

  if ! has_command python3; then
    echo "python3 is unavailable and AWS CLI v2 installer failed." >&2
    exit 1
  fi

  local venv_dir
  venv_dir="$TOOL_VENV_ROOT/awscli"
  create_python_venv "$venv_dir"
  "$venv_dir/bin/python" -m pip install --upgrade pip awscli
  mkdir -p "$USER_BIN"
  ln -sf "$venv_dir/bin/aws" "$USER_BIN/aws"
  append_user_bin_to_shell_path
  verify_aws_cli_fallback
}

append_user_bin_to_shell_path() {
  local path_line='export PATH="$HOME/.local/bin:$PATH"'

  if [ -f "$HOME/.bashrc" ] && ! grep -Fq "$path_line" "$HOME/.bashrc"; then
    echo "$path_line" >> "$HOME/.bashrc"
  fi

  if [ -f "$HOME/.zshrc" ] && ! grep -Fq "$path_line" "$HOME/.zshrc"; then
    echo "$path_line" >> "$HOME/.zshrc"
  fi
}

verify_aws_cli_fallback() {
  if ! command_works aws; then
    echo "AWS CLI fallback installation completed, but aws still cannot run." >&2
    exit 1
  fi

  aws --version

  if ! aws configure sso help >/dev/null 2>&1; then
    echo ""
    echo "WARNING: This AWS CLI install may not support 'aws configure sso'."
    echo "If SSO login is required, rebuild the Codespace so the devcontainer aws-cli feature can install AWS CLI v2."
  fi
}

install_sam_cli() {
  if command_works sam; then
    sam --version
    return
  fi

  log "Installing AWS SAM CLI in a virtual environment"

  if ! has_command python3; then
    echo "python3 is unavailable and SAM CLI is not installed." >&2
    exit 1
  fi

  local venv_dir
  venv_dir="$TOOL_VENV_ROOT/sam-cli"
  create_python_venv "$venv_dir"
  "$venv_dir/bin/python" -m pip install --upgrade pip aws-sam-cli
  mkdir -p "$USER_BIN"
  ln -sf "$venv_dir/bin/sam" "$USER_BIN/sam"
  append_user_bin_to_shell_path

  if ! command_works sam; then
    echo "SAM CLI installation completed, but sam still cannot run." >&2
    exit 1
  fi

  sam --version
}

create_python_venv() {
  local venv_dir="$1"
  rm -rf "$venv_dir"
  mkdir -p "$(dirname "$venv_dir")"

  if python3 -m venv "$venv_dir" >/dev/null 2>&1; then
    return
  fi

  if python3 -m virtualenv "$venv_dir" >/dev/null 2>&1; then
    return
  fi

  echo "Could not create a Python virtual environment." >&2
  echo "Install python3 venv support or rebuild the Codespace." >&2
  exit 1
}

install_node() {
  if has_command node; then
    node --version
    return
  fi

  log "Installing Node.js 20"

  if has_command apt-get; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | run_root bash -
    run_root apt-get install -y nodejs
  elif has_command apk; then
    run_root apk add --no-cache nodejs npm
  else
    echo "Cannot install Node.js automatically. Install Node.js 20 manually." >&2
    exit 1
  fi

  node --version
}

setup_yarn() {
  log "Setting up Yarn"

  if ! has_command corepack; then
    if has_command npm; then
      npm install -g corepack
    else
      echo "npm not found, installing corepack manually..."
      curl -fsSL "https://registry.npmjs.org/corepack/-/corepack-0.31.0.tgz" -o /tmp/corepack.tgz
      mkdir -p /tmp/corepack-pkg && tar -xzf /tmp/corepack.tgz -C /tmp/corepack-pkg
      run_root node /tmp/corepack-pkg/package/dist/corepack.js enable
      rm -rf /tmp/corepack.tgz /tmp/corepack-pkg
    fi
  fi

  corepack enable
  corepack prepare "yarn@${YARN_VERSION}" --activate
  yarn --version
}

install_dependencies() {
  log "Installing project dependencies"
  cd "$PROJECT_ROOT"
  yarn install
}

check_docker() {
  log "Checking Docker"
  if command_works docker; then
    docker --version
  else
    echo "⚠️  Docker is not available."
    echo "   sam build --use-container will not work."
    echo "   Rebuild the Codespace if Docker is required."
  fi
}

print_next_steps() {
  log "Setup complete"
  echo ""
  echo "  AWS CLI : $(aws --version 2>&1 | head -1 || echo 'not installed')"
  echo "  SAM CLI : $(sam --version 2>/dev/null || echo 'not installed')"
  echo "  Docker  : $(docker --version 2>/dev/null || echo 'not available')"
  echo "  Node    : $(node --version 2>/dev/null || echo 'not installed')"
  echo "  Yarn    : $(yarn --version 2>/dev/null || echo 'not installed')"
  echo "  Region  : ${AWS_REGION}"
  echo ""
  echo "✅ GUIDE.md를 열어 실습을 시작하세요."
}

main() {
  cd "$PROJECT_ROOT"

  ensure_system_packages
  install_node
  install_aws_cli
  install_sam_cli
  setup_yarn
  install_dependencies
  check_docker
  print_next_steps
}

main "$@"
