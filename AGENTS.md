# Agent Instructions for meta-arduino

> **Fork:** this checkout is the jrosa-digiwest/meta-arduino fork. Read
> [FORK.md](FORK.md) for its branch workflow and its rules for upstream PRs.
> In particular: never open a PR, issue or comment in arduino/meta-arduino
> or any other Arduino repository unless the user explicitly asked for it
> and both the agent and the user have validated the change.

Project overview, layer architecture, and contribution guidelines live in
[README.md](README.md) and [DEVELOPERS.md](DEVELOPERS.md) — read those first.

## Commit style

- One topic per commit: never bundle multiple features, or unrelated
  bug fixes, into a single commit.
- Keep the commit message to a one-line subject (`<scope>: summary of the
  change`); skip the body unless a reviewer could not infer the change from
  the diff alone.
- Trailer order matters, so the sign-off is always the last line:

  ```
  <scope>: summary of the change

  Assisted-by: AGENT_NAME:MODEL_VERSION
  Signed-off-by: Author Name <author@example.com>
  ```

- Take `Signed-off-by` from the local git configuration (`git config
  user.name` / `user.email`); never fabricate a name or email.
