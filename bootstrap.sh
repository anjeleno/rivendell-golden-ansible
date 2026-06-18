#!/bin/bash
# Entry point for unattended use: paste this into a cloud provider's
# "User Data" / "Startup Script" field (e.g. DigitalOcean Droplet
# creation -> Additional Options -> Startup scripts (Free), or run
# it directly as root on a fresh Ubuntu 24.04 box (UTM VM, physical
# hardware install). It installs Ansible, then uses `ansible-pull` to
# fetch this repo and run site.yml against the local machine -- no
# inbound SSH access or separate control node required.
#
# Fill in the variables below before using this script. Everything
# else (build user, hostname, audio hardware, etc.) is configured in
# group_vars/all.yml in this repo -- override any of it here too via
# extra -e flags on the ansible-pull line at the bottom, if needed.
set -euo pipefail

# --- EDIT THESE -----------------------------------------------------
# This installer repo itself (safe to leave as-is once published).
INSTALLER_REPO="https://github.com/anjeleno/rivendell-golden-ansible.git"

# Only needed if you want to override the defaults in group_vars/all.yml.
RIVENDELL_GIT_REPO=""
RIVENDELL_GIT_REF=""

# Private deploy key for RIVENDELL_GIT_REPO, if it's a private repo.
# Paste the entire key -- including the BEGIN/END lines -- between the
# quotes below. Leave empty if the repo is public, or if this machine
# already has its own working git credentials configured.
RIVENDELL_DEPLOY_KEY=""
# ----------------------------------------------------------------------

apt-get update
apt-get install -y --no-install-recommends git ansible

extra_vars=()
[ -n "$RIVENDELL_GIT_REPO" ] && extra_vars+=(-e "rivendell_git_repo=$RIVENDELL_GIT_REPO")
[ -n "$RIVENDELL_GIT_REF" ] && extra_vars+=(-e "rivendell_git_ref=$RIVENDELL_GIT_REF")
[ -n "$RIVENDELL_DEPLOY_KEY" ] && extra_vars+=(-e "rivendell_deploy_key=$RIVENDELL_DEPLOY_KEY")

ansible-galaxy collection install community.general
ansible-pull -U "$INSTALLER_REPO" -i "localhost," site.yml "${extra_vars[@]}"
