# Agent skills

Aegivue keeps a small, reviewed set of project-scoped agent skills for its
Flutter, PostgreSQL, media, and engineering workflows. The installer writes to
the checkout rather than a user-global skill directory. The curated sources and
content hashes are recorded in [`skills-lock.json`](../../skills-lock.json).

## Install

Install for Codex from the repository root:

```sh
./scripts/install-agent-skills.sh
```

Pass one or more [skills CLI](https://skills.sh/) agent identifiers to target
other compatible agents as well:

```sh
./scripts/install-agent-skills.sh codex claude-code
```

The helper requires Node.js/npm, Git, and network access. It uses project scope
only (there is no `--global` flag), installs the selected payloads under
`.agents/skills`, and may create adapter links for the requested agents. The
downloaded payloads are local generated files; do not commit them. Rerunning the
helper is safe, but it refreshes content from the upstream default branches, so
treat a rerun as an update and review changes to `skills-lock.json`.

Equivalent manual commands for Codex are:

```sh
npx --yes skills add https://github.com/flutter/agent-plugins \
  --agent codex --yes \
  --skill flutter-apply-architecture-best-practices \
  flutter-setup-declarative-routing dart-run-static-analysis

npx --yes skills add https://github.com/neondatabase/postgres-skills \
  --agent codex --yes \
  --skill postgres-best-practices

npx --yes skills add https://github.com/wyattowalsh/agents \
  --agent codex --yes \
  --skill ffmpeg

npx --yes skills add https://github.com/mattpocock/skills \
  --agent codex --yes \
  --skill diagnosing-bugs code-review codebase-design \
  resolving-merge-conflicts

npx --yes skills add https://github.com/obra/superpowers \
  --agent codex --yes \
  --skill systematic-debugging test-driven-development \
  verification-before-completion
```

## Curated skills

| Area | Skill and source | Use in Aegivue |
| --- | --- | --- |
| Flutter | [`flutter-apply-architecture-best-practices`](https://github.com/flutter/agent-plugins) | Pragmatic UI, ViewModel, and repository separation during Flutter feature work and focused refactors. Repository instructions still decide which optional layers are warranted. |
| Flutter | [`flutter-setup-declarative-routing`](https://github.com/flutter/agent-plugins) | Router changes, deep links, browser history, and URL-based navigation in the web app. |
| Dart | [`dart-run-static-analysis`](https://github.com/flutter/agent-plugins) | Analyzer findings, lint configuration, and safe mechanical Dart fixes. |
| PostgreSQL | [`postgres-best-practices`](https://github.com/neondatabase/postgres-skills) | Schema, migration, indexing, query, transaction, and production-compatibility work. |
| Media | [`ffmpeg`](https://github.com/wyattowalsh/agents) | Probe real media and diagnose or perform bounded FFmpeg/ffprobe operations. Preserve originals unless replacement is explicit. |
| Debugging | [`diagnosing-bugs`](https://github.com/mattpocock/skills) | Build a tight reproduction and test hypotheses for difficult bugs or regressions. Redact credentials and private camera data from artifacts. |
| Review | [`code-review`](https://github.com/mattpocock/skills) | Review a diff against repository standards and the task specification. |
| Design | [`codebase-design`](https://github.com/mattpocock/skills) | Evaluate module seams and interfaces when design work or a requested refactor calls for it. |
| Git | [`resolving-merge-conflicts`](https://github.com/mattpocock/skills) | Understand both sides of an active merge/rebase conflict before resolving it. Repository and user instructions still control staging and commits. |
| Debugging | [`systematic-debugging`](https://github.com/obra/superpowers) | Trace root cause before changing code for failures and unexpected behavior. |
| Testing | [`test-driven-development`](https://github.com/obra/superpowers) | Implement behavior in small red-green-refactor steps where a reliable test seam exists. |
| Verification | [`verification-before-completion`](https://github.com/obra/superpowers) | Run fresh, relevant checks before claiming a change is complete or passing. |

Use only the skills relevant to the current task. Overlapping debugging skills
are alternatives, not a requirement to run two full processes for every defect.
Do not add skills merely because they are popular, and do not add a Docker skill
without a separate content, security, and quality review.

## Unavailable requested skills

The following originally proposed names were not present in
`flutter/agent-plugins` at commit `3f58a55` when checked on 2026-09-27, so they
are intentionally not installed:

- `flutter-architecting-apps`
- `flutter-architecture`
- `flutter-managing-state`
- `flutter-testing`

No replacement has been silently substituted. Reassess the upstream catalog
and Aegivue's needs before proposing alternatives.

## Verification snapshot

The twelve installed names and their CLI commands were verified on 2026-09-28
against these upstream revisions:

- `flutter/agent-plugins` at `3f58a55`
- `neondatabase/postgres-skills` at `27fe45e`
- `wyattowalsh/agents` at `c383958`
- `mattpocock/skills` at `c55ee46`
- `obra/superpowers` at `8ca22db`

The repository URLs and default branches can change. Repeat the source and
content review rather than treating this snapshot as a permanent approval.

## Review and update policy

Skills run with the coding agent's permissions. Before installing for the first
time or accepting an update:

1. Confirm the exact source repository and skill name.
2. Read the changed `SKILL.md` plus every bundled script, hook, executable, and
   referenced instruction that the skill tells an agent to run.
3. Check for network access, secret handling, destructive filesystem or Git
   operations, privilege escalation, and instructions that conflict with
   `AGENTS.md`.
4. Review the skills CLI risk report as one input, not as a substitute for
   inspection. At the verification snapshot, `code-review` and
   `resolving-merge-conflicts` received elevated automated ratings. They expose
   agent/sub-agent or Git-operation capabilities, and their installed files must
   be reviewed on every update.
5. Run the installer in a clean worktree and inspect `git diff` and
   `skills-lock.json`. Keep only skills with a current Aegivue use case.

The initial review also noted executable/helper content in `ffmpeg`,
`diagnosing-bugs`, and `systematic-debugging`. Inspect those files again if their
hashes change. Never expose camera credentials, tokens, private stream URLs, or
captured customer media to a skill or public pull request.
