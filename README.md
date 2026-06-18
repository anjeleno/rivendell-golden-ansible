# Rivendell golden-image installer

An Ansible playbook that provisions a fresh Ubuntu 24.04 machine into a
working Rivendell radio automation install, from source, end to end:
build dependencies, desktop/xrdp/MATE, MariaDB, compile + install,
Apache/`rdxport.cgi` wiring, the `rivendell`/`pypad` system users and
`/var/snd`, a freshly generated database password, schema + seed data +
test tone, PulseAudio/ALSA handoff, and service enablement at boot.

It's a direct translation of a manual golden-image build log, refined
across several from-source installs to catch the gaps that the
project's own `.deb` packaging normally papers over (see the comments
in `roles/provision/templates/fix-rivendell-user.sh.j2` for the details
on each one).

Tested target: Ubuntu 24.04, on a DigitalOcean Droplet, a UTM VM, and
physical hardware.

## Important: this builds a specific git repo, which may be private

`group_vars/all.yml` defaults `rivendell_git_repo` to a private fork.
**If you don't have read access to that repo, the build step will fail
at the git clone.** Before running this against your own machine, set:

```yaml
rivendell_git_repo: https://github.com/ElvishArtisan/rivendell.git  # public upstream
rivendell_git_ref: v4                                                # or any tag/branch you want
```

or point it at your own fork. If your repo is private, see "Private
repo access" below.

## Usage

Pick one of these two methods -- they're alternatives, not sequential
steps.

### Method 1: control node pushes to a target over SSH

For a Droplet, UTM VM, or physical box that's already SSH-reachable as
root (or any sudo-capable user):

1. Add the target to `inventory/hosts.ini`.
2. `ansible-galaxy install -r requirements.yml`
3. `ansible-playbook site.yml`

### Method 2: paste into a Droplet's startup script (no SSH needed)

`bootstrap.sh` is meant to be pasted directly into DigitalOcean's
Droplet creation screen (Additional Options -> Startup scripts (Free)),
or run as-is on a freshly installed UTM VM / physical box. It installs
Ansible and uses `ansible-pull` to fetch this repo and run `site.yml`
against the local machine -- no inbound SSH or separate control node
required.

Edit the variables at the top of `bootstrap.sh` first (repo URL/ref
overrides, deploy key if needed), then paste the whole script in. You
do **not** need to touch `inventory/hosts.ini` for this method --
`bootstrap.sh` passes `-i "localhost,"` explicitly, which overrides
whatever's (or isn't) in that file. It exists purely for Method 1.

## Private repo access

`rivendell_deploy_key` (in `group_vars/all.yml`, or passed via
`-e`/`bootstrap.sh`) is a private SSH key with read access to
`rivendell_git_repo`. When set, the `deploy_key` role writes it to the
build user's `~/.ssh/`, scoped to `github.com` only via `~/.ssh/config`
so it's never used for anything else. Leave it blank if your repo is
public, or if the box already has working git credentials some other
way (e.g. you're running this from your own machine with an agent
already forwarding your normal key).

**Never commit a real key into this repo.** Pass it at runtime, ideally
via an Ansible Vault file (`ansible-playbook site.yml -e @secrets.yml
--ask-vault-pass`) rather than plain `-e` on the command line where
it'd show up in shell history.

## What's intentionally not automated

- Phase 0 (creating the Droplet / installing a base OS on a UTM VM or
  physical box) -- this playbook starts from "fresh Ubuntu 24.04,
  reachable as root," not before.
- Disk imaging/cloning a literal golden image (`dd`, streaming over
  SSH, importing into UTM) -- this playbook is the replacement for
  that workflow, not an addition to it. Run it fresh on each target
  instead of cloning a disk image.
- Per-station configuration inside Rivendell itself (Dropboxes, carts,
  schedule codes, RDAdmin host settings) -- this gets you to a running
  Rivendell with a test tone in the library, not a configured station.

## Re-running this playbook later

Everything except the database/test-tone step is safe to re-run (it'll
just confirm the existing state and move on). The database step is
deliberately **not** idempotent -- it drops and rebuilds the schema
from scratch -- so it's guarded by a `/etc/rivendell-installer-provisioned`
marker file and only ever runs once per host. Delete that marker
yourself if you genuinely want to wipe and rebuild an existing
install's database.
