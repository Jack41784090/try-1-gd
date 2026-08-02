---
name: sort-and-commit
description: "Survey the full working-tree diff and split it into multiple well-scoped, conventional commits instead of one giant commit. Use when the user says 'sort and commit', asks to commit everything, or the working tree has accumulated unrelated changes across many files that need to be grouped logically before committing."
---

# Sort and Commit

Look at everything that's changed, group it into logically coherent commits (not one
mega-commit), and commit each group with a message that follows this repo's convention.
Invoking this skill IS the user's explicit request to create commits — proceed without
asking for a go-ahead on the overall task, but still stop and ask if a specific file's
grouping or intent is genuinely ambiguous.

## Steps

1. **Survey the full picture.**
   - `git status` (never `-uall`)
   - `git diff` and `git diff --staged`
   - `git log --oneline -15` to match the repo's existing message style and recent scopes

2. **Cluster the changes.** Group changed/untracked files into logical commits using two axes:
   - **Same subsystem/feature** — files that implement one coherent change together
     (e.g. a `.gd` script plus the `.tres`/`.tscn` resources it drives)
   - **Same type of change** — this repo's commit taxonomy from `CLAUDE.md`:
     `feat`, `fix`, `refactor`, `art`, `chore`, `test`, `docs`, `data`
   - Scopes (pick the most specific, optional): `combat`, `strategy`, `economy`, `vn`,
     `animation`, `stage`, `rig`, `ai`, `ui`, `tools`
   - A single logical change may legitimately span many files across directories.
     Unrelated changes must never land in the same commit just because they were
     touched in the same session — split them even if that means many small commits.
   - Pure `.tres`/`.tscn` resource edits with no accompanying script logic change get
     `data`; docs-only edits (`CLAUDE.md`, `AGENTS.md`, inline docs) get `docs`.

3. **Screen before staging.** Read the diff for each candidate file. Never stage or
   commit anything that looks like a credential, token, `.env`, or other secret —
   exclude it and flag it to the user instead. If a file looks like unrelated
   in-progress/scratch work the user hasn't mentioned, ask rather than guessing.

4. **Stage and commit one cluster at a time.**
   - Stage by explicit path (`git add <file> <file> ...`) — never `git add -A` or
     `git add .`, so unrelated files can't slip into the wrong commit.
   - Commit message format (from `CLAUDE.md`):
     ```
     <type>(<scope>): <subject>
     ```
     Imperative mood, lowercase first letter, no trailing period, ≤72 chars total.
   - Always pass the message via heredoc, and end the body with:
     ```
     Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
     ```
   - Never use `--amend`, `--no-verify`, or `--no-gpg-sign`. If a pre-commit hook
     fails, fix the underlying issue, re-stage, and create a fresh commit — don't
     bypass the hook.

5. **Repeat** until every intentional change is committed. Leave genuinely ambiguous
   files unstaged rather than guessing, and call them out at the end.

6. **Wrap up.** Run `git status` to confirm a clean (or intentionally-partial) tree,
   then report a short list of the commits created (short hash + subject) and any
   files left uncommitted with the reason why.

## Non-negotiables

- Never push. This skill only creates local commits.
- Never run destructive git commands (`reset --hard`, `checkout --`, `clean -f`) as
  part of sorting — if a file shouldn't be committed yet, just leave it unstaged.
- If the entire working tree is already one coherent change, a single commit is a
  correct outcome of "sorting" — don't split for the sake of splitting.
