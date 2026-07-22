# Privileged diagnostic authorization

Some DeckDoc evidence is visible only to root. DeckDoc can either ask for `sudo` on every full report,
or the owner can approve a small read-only command set once. This is useful when a helper or diagnostic
agent needs to collect evidence later without learning, storing, or repeatedly requesting the user's
password.

## What approval installs

```bash
sudo ./privileged/install-authorized.sh install
```

That one interactive approval installs:

- a root-owned snapshot of `deckdoc.sh` and its diagnostic modules;
- a root-owned broker at `/var/lib/deckdoc-authorized/bin/deckdoc-authorized`;
- a SHA-256 manifest checked before each report;
- exact `sudoers` entries for the approving user.

The allowlist contains five exact operations: a normal read-only report, a read-only report with the
physical-black symptom declared, a manual incident-probe capture, probe status, and snapshot version.
It does **not** allow arbitrary arguments, output paths, environment variables, programs, shells, or
DeckDoc remediation modes.

## Use it later without a password prompt

```bash
./privileged/deckdoc-authorized-client.sh report
./privileged/deckdoc-authorized-client.sh status
./privileged/deckdoc-authorized-client.sh probe-capture
```

The client invokes `sudo -n`, receives the report over standard output, and writes it as a private file
under `logs/`. The privileged broker never accepts a user-selected destination. An agent can invoke
these exact client actions, but the authorization is not a general delegation of root access.

## Security and update boundary

- The installed application and broker are owned by root and verified against their manifest.
- The repository checkout remains user-writable but is not executed as root by the authorized command.
- A Git pull does not silently change the privileged snapshot.
- Updating that snapshot requires running the interactive install command again.
- Remediation remains outside the passwordless allowlist and requires a separate explicit action.
- Reports are private but unredacted. Review them before sharing.

If the integrity check fails, the broker refuses to run and asks for reinstallation. This detects a
changed or incomplete installed snapshot; it is not a substitute for package signing or host security.

## Remove authorization

```bash
sudo ./privileged/install-authorized.sh uninstall
```

This removes the current user's `sudoers` rule while preserving the installed snapshot. After every
authorized user has been removed, delete the snapshot separately:

```bash
sudo ./privileged/install-authorized.sh purge
```

Removal is deliberately split so revoking access does not unexpectedly destroy diagnostic state.
