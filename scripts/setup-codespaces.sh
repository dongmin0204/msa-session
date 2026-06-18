#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YARN_VERSION="4.6.0"
AWS_REGION="${AWS_DEFAULT_REGION:-ap-northeast-2}"
USER_BIN="$HOME/.local/bin"

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

ensure_apt_packages() {
  if ! has_command apt-get; then
    return
  fi

  log "Installing base packages"
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl unzip python3 python3-pip python3-venv
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
  sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer
  sudo rm -rf /usr/local/aws-cli
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

  sudo "$tmp_dir/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
  rm -rf "$tmp_dir"
  aws --version
}

install_aws_cli_fallback() {
  if has_command apt-get; then
    install_aws_cli_with_apt
    return
  fi

  install_aws_cli_with_pip
}

install_aws_cli_with_apt() {
  log "Installing AWS CLI from apt"
  sudo apt-get update
  sudo apt-get install -y awscli

  verify_aws_cli_fallback
}

install_aws_cli_with_pip() {
  log "Installing AWS CLI with pip"

  if ! has_command python3; then
    echo "python3 is unavailable and AWS CLI v2 installer failed." >&2
    exit 1
  fi

  if ! python3 -m pip --version >/dev/null 2>&1; then
    python3 -m ensurepip --user --upgrade
  fi

  python3 -m pip install --user --upgrade awscli
  mkdir -p "$USER_BIN"
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

  log "Installing AWS SAM CLI"
  python3 -m pip install --user --upgrade aws-sam-cli

  if ! has_command sam; then
    append_user_bin_to_shell_path
  fi

  sam --version
}

setup_yarn() {
  log "Setting up Yarn"
  corepack enable
  corepack prepare "yarn@${YARN_VERSION}" --activate
  yarn --version
}

install_dependencies() {
  log "Installing project dependencies"
  cd "$PROJECT_ROOT"
  yarn install
}

print_next_steps() {
  log "Setup complete"
  echo "AWS_DEFAULT_REGION=${AWS_REGION}"
  echo ""
  echo "Next commands:"
  echo "  yarn monolith"
  echo "  yarn msa"
  echo "  aws configure sso"
  echo "  aws sts get-caller-identity"
}

main() {
  cd "$PROJECT_ROOT"

  ensure_apt_packages
  install_aws_cli
  install_sam_cli
  setup_yarn
  install_dependencies
  print_next_steps
}

main "$@"
