# 0002 — ARM64 builds, on either Ubuntu or Debian

**Date:** 2026-06-20

## Goal

Add ARM64 as a supported target architecture, on either Ubuntu 24.04
or Debian 12 — selectable, not a fork of the playbook. Both as
options, via a new group_var, rather than picking one.

## Background — verified against the real build script, not assumed

Read `buildlatest.sh` directly
(`https://raw.githubusercontent.com/alastairtech/rivendell-arm/refs/heads/main/buildlatest.sh`,
86 lines, fetched and read in full) rather than assume "ARM support"
is purely a CPU-architecture question.

### This script targets Debian 12 ("bookworm"), not Ubuntu

Confirmed by the repository line it adds:
`deb http://deb-multimedia.org bookworm main non-free`. This matters
beyond just the codename — `deb-multimedia.org` is a well-known
third-party repo specifically for non-free multimedia codec packages
that Debian's own free-software policy excludes from its main repos.
Ubuntu ships the equivalent packages
(`libmp3lame-dev`/`libtwolame-dev`/etc.) directly via
`universe`/`multiverse`, no third-party repo needed. This is a real
distribution-policy difference to design around, not a detail to
paper over with a single `when: ansible_architecture == 'aarch64'`
conditional.

### The package list is nearly identical to this playbook's existing one

Comparing `buildlatest.sh`'s `apt-get install` line against
`roles/base/tasks/main.yml`'s existing list: the overlap is large
enough (down to oddities like `ubuntu-dev-tools` appearing in a
*Debian* script) to suggest shared lineage from the same community
build tutorials this playbook itself was built from, not an
independently-engineered ARM-specific list. The real divergence is
narrow:

- `python3-pymysql` (his) vs. `python3-mysqldb` (ours) — same purpose,
  different package; needs checking which one Debian 12 actually
  provides vs. Ubuntu 24.04.
- The `deb-multimedia` repo + its codec packages — Debian-only need.
- No equivalent to `ubuntu-mate-core`, `xorgxrdp`, or any desktop
  package at all — his script doesn't install a desktop, full stop
  (see scope note below). Debian's MATE meta-package name needs
  confirming at implementation time, not assumed.

### A real configure-flag difference, not yet understood

His `./configure` line adds
`MUSICBRAINZ_LIBS="-ldiscid -lmusicbrainz5cc -lcoverartcc"` explicitly
— this playbook's `rivendell_configure_args` doesn't set this. Two
real possibilities, not distinguished yet: (a) an ARM-specific or
Debian-specific `pkg-config`/`.pc` file gap that requires the explicit
override, or (b) a workaround for an older Rivendell release's build
quirk that may not apply to the current `v4` branch this playbook
builds. Flagged as an open item below rather than copied in
speculatively.

### Scope limitation: this script only builds and packages, nothing else

`buildlatest.sh` ends with `debuild -us -uc -nc -b` — it builds
Rivendell from source and produces `.deb` packages, full stop. It does
**not** create the `rivendell`/`pypad` system users, seed the
database, enable the systemd service, or install a desktop — none of
what `roles/provision`, `roles/database`, `roles/webserver`, or
`roles/desktop` already handle. So even using this script as a
reference, it only informs the `build` role's package list and
configure flags for an ARM/Debian target specifically — it doesn't
replace or reduce the need for any other existing role.

(Tangential but worth recording since it's directly validating
information for a separate, already-scoped conversation: `debuild -us
-uc -nc -b` confirms Rivendell's own `debian/` packaging machinery
already works as-is on ARM/Debian, via the standard `debuild` workflow
— relevant to the separate "build a `.deb` from the Ansible build
instead of compiling from source" discussion, not part of this spec.)

## Implementation plan

### 1. New group_var (`group_vars/all.yml`)

```yaml
rivendell_target_os: ubuntu  # ubuntu | debian
```

Defaults to `ubuntu`, preserving every existing behavior with zero
config changes for anyone not setting this. Kept as an explicit,
manually-set var rather than auto-detected from `ansible_distribution`
— matches the existing `rivendell_install_mode` convention (also
explicit, not auto-detected), for consistency rather than introducing
a second pattern.

ARM64 itself needs no separate group_var — Ansible already exposes
`ansible_architecture`, and nothing in this spec's package/repo
differences are architecture-specific on their own merits (they're
OS-specific); ARM64 support falls out of getting the Debian path
working at all, on either architecture Debian itself supports.

### 2. `base` role: branch the package list and add the Debian-only repo

- Split the current single package list into a common list plus an
  `ubuntu`-specific and `debian`-specific list, `when:
  rivendell_target_os == '...'` gated, for the handful of items that
  actually differ (see open items below for which ones still need
  confirming).
- New task, Debian-only: add the `deb-multimedia.org` repo and its
  keyring, mirroring `buildlatest.sh`'s approach, gated to
  `rivendell_target_os == 'debian'`.

### 3. `build` role: conditionally apply the `MUSICBRAINZ_LIBS` override

Pending the open item below being resolved — if it turns out to be a
genuine Debian/ARM linking gap rather than a stale workaround, add it
to `rivendell_configure_args` conditionally for `rivendell_target_os
== 'debian'` rather than unconditionally for everyone.

### 4. `desktop` role: Debian-equivalent package names

Same branching approach as item 2 — `ubuntu-mate-core`/`xorgxrdp` need
Debian 12 equivalents identified before this can be written, not
guessed at.

## Confirmed out of scope for this pass

- Actually testing on real ARM hardware or a VM — that's on the user
  to do once this is implemented; nothing here substitutes for that.
- Investigating *why* `MUSICBRAINZ_LIBS` is needed beyond confirming
  whether it's still needed at all — see open items.
- Any change to `roles/database`/`roles/provision`/`roles/webserver` —
  nothing found in `buildlatest.sh` suggests these need OS-specific
  branching; they're not mentioned at all in that script because it
  doesn't provision a running system in the first place.

## Open items for implementation time

- Confirm Debian 12's actual package names for every item in
  `roles/base`'s and `roles/desktop`'s lists that might differ from
  Ubuntu 24.04's — not verified independently in this pass beyond the
  `python3-pymysql`/`python3-mysqldb` and desktop-meta-package
  differences already flagged above. Needs a real Debian 12 box (or
  `apt-cache`/`rmadison` lookups) to confirm each one, not assumed from
  this script alone.
- Confirm whether `MUSICBRAINZ_LIBS="-ldiscid -lmusicbrainz5cc
  -lcoverartcc"` is still needed against the current upstream `v4`
  branch this playbook builds, and whether it's Debian-specific,
  ARM-specific, or both — `buildlatest.sh` doesn't explain why it's
  there, and the Rivendell release it was tested against isn't stated.
- Confirm Debian 12's shipped Qt5 version doesn't introduce other
  incompatibilities against what this playbook's `build` role already
  assumes (Ubuntu 24.04's Qt5 version) — not checked in this pass.
