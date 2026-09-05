#!/usr/bin/env bash
# Prepares a control workstation for this repository.
set -euo pipefail

echo "==> Installing pre-commit hooks"
pip install pre-commit --break-system-packages --quiet
pre-commit install

echo "==> Installing Ansible collections"
ansible-galaxy collection install -r requirements.yml

echo "==> Checking secret tooling"
command -v sops >/dev/null 2>&1 || echo "missing: sops"
command -v age  >/dev/null 2>&1 || echo "missing: age"

echo "==> Scanning full history for secrets"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source . -v
else
  echo "missing: gitleaks"
  exit 1
fi
