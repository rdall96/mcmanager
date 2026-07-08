---
name: gitlab-issue-sync
description: Scan this project's ISSUES.md log for new, unfiled findings and create corresponding GitLab issues via the API. Use when the user asks to "sync issues", "check ISSUES.md for updates", "file the new bugs", or similar — ISSUES.md is appended to over time by a separate agent, so this only files what isn't already in GitLab. Requires a GitLab API token from the user before any write calls.
tools: Read, Bash, Grep
---

# GitLab issue sync

Turns entries in a running markdown "issues found" log into GitLab issues,
without duplicating ones already filed. Issues are always read from a file
named `ISSUES.md` at the repo root — this filename is a fixed convention of
this skill, not a per-project setting. Written for this project
(`mcmanager`); see **Adapting to another project** at the bottom for what to
change when copying this skill elsewhere.

**This skill makes real, visible API calls against a shared GitLab project.**
Always confirm scope with the user before the create-issue calls — getting
the mapping/labeling wrong is easy and hard to notice; getting the API call
wrong is not.

## Project configuration (mcmanager)

- Source file: `ISSUES.md` at the repo root (see fixed convention above).
  Append-only log maintained by a separate agent — always re-read it fresh,
  never rely on a prior session's understanding of its contents.
- GitLab group: `https://gitlab.com/mcmanager`
- Target project for every entry in this file: `mcmanager/mcmanager` (the
  backend). The group also contains `mcmanager-web-app`, but nothing in
  `ISSUES.md` currently targets it — all entries describe backend bugs found
  while building the frontend.
- Labels: fetched live from the project at the start of every sync (Workflow
  step 3) — this skill never hardcodes a label list. For reference only, as
  of 2026-07-08 `mcmanager/mcmanager`'s labels are: `bug`, `deployment`,
  `documentation`, `duplicate`, `enhancement`, `feature`, `task`. Treat the
  live fetch as authoritative; this snapshot can go stale.

## Workflow

### 1. Get the API token

If not already supplied in the conversation, ask for a GitLab personal/project
access token with `api` scope. Use it only in-memory for `curl` calls this
session — never write it to a file, log, or commit.

### 2. Read the source file fresh

Read `ISSUES.md` in full. Parse each `##` section, and each top-level bullet
within a section, into one candidate issue. Section headings are a hint
toward a bullet's nature, not an automatic label assignment — see step 6.

### 3. Fetch the project's live label set

```bash
curl -sS --header "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.com/api/v4/projects/<project-path-url-encoded>/labels"
```

Use this response as the labeling vocabulary for step 6. Don't assume any
particular label exists — the list in "Project configuration" above is only
a reference snapshot and can be stale; this fetch is authoritative.

### 4. Derive a stable title per bullet

Title = the bullet's bold lead-in sentence, trimmed to a concise summary (not
the full bullet body). This must be deterministic — the same bullet has to
produce the same title on every future scan, since title text is the only
signal used for duplicate detection.

### 5. Duplicate detection

Duplicate detection is based on a back-reference written into `ISSUES.md`
itself (see step 8), not a GitLab search. Immediately below each bullet's
text, look for a marker line of the form:

```
  _Filed: mcmanager/mcmanager#<iid>_
```

Skip any bullet that already has one. Also skip any bullet the source file
itself marks resolved/removed.

### 6. Choose label(s) per bullet, by content

For each surviving bullet, judge its actual content against the full label
set fetched in step 3, and assign whichever label(s) genuinely fit — for
example a behavioral defect suits a `bug`-type label, a spec/doc inaccuracy
suits a `documentation`-type label, a missing capability or design gap suits
a `feature`/`enhancement`-type label, a CI/pipeline/infra problem suits a
`deployment`-type label. A bullet can take more than one label if it
genuinely spans categories.

Section headings are a hint, not a rule — don't mechanically map "everything
in section X always gets label Y." Judge each bullet on its own text.

If nothing in the fetched set is a good fit, don't force an ill-fitting label
and don't unilaterally create a new one — note it as unlabeled and raise it
during step 7 for the user to decide (assign an existing label, approve
creating a new one, or leave it unlabeled).

### 7. Confirm scope with the user

Before creating anything, report: how many new (non-duplicate) entries were
found, the label(s) chosen per entry (and any left unlabeled), and the
target project. Get a go-ahead.

### 8. Create the issues, one at a time, writing back immediately

For each surviving bullet:

1. Create the issue:

   ```bash
   curl -sS --request POST --header "PRIVATE-TOKEN: $TOKEN" \
     --data-urlencode "title=<title>" \
     --data-urlencode "description=<full bullet text>" \
     --data "labels=<label1>,<label2>" \
     "https://gitlab.com/api/v4/projects/mcmanager%2Fmcmanager/issues"
   ```

2. Take the `iid` from the response and immediately edit `ISSUES.md`,
   inserting a marker line right after that bullet's text:

   ```
     _Filed: mcmanager/mcmanager#<iid>_
   ```

   Do this one bullet at a time (create, then write back, then move to the
   next) rather than batching all creates first — `ISSUES.md` may also be
   edited concurrently by the separate agent that appends to it, so keeping
   the window between reading and writing short reduces the chance of a
   stale-file conflict. Re-read the file immediately before each edit rather
   than reusing the copy read in step 2.

Report back the created issue URLs/IIDs grouped by label.

## Key constraints (apply to any project, not just mcmanager)

- **GitLab issues always belong to exactly one project.** There's no API for
  creating a project-agnostic "group-level" issue and assigning it after the
  fact. A group's issue list is just an aggregated view across its projects;
  creation still resolves to `POST /projects/:id/issues` on one project.
  Group epics are a separate, real group-level object with cross-project
  child issues — only use them if explicitly asked for.
- **One issue per bullet**, not one per section.
- **Labels are chosen per bullet by content, judged against the project's
  live label set** (fetched fresh each sync, never hardcoded) — not by a
  fixed section→label table. Section headings are only a hint. Don't
  unilaterally create a new label if nothing fits; ask the user instead.
- **Never persist the API token** anywhere other than the in-memory shell
  environment for the duration of the session.
- **Issues are always read from `ISSUES.md`** at the repo root — a fixed
  filename convention for this skill, not a per-project setting.
- **Write the GitLab issue reference back into `ISSUES.md` immediately after
  each create call**, one bullet at a time, using the `_Filed:
  project%2Fpath#<iid>_` marker format from step 8. Re-read the file right
  before each edit since a separate agent may be appending to it
  concurrently.

## Adapting to another project

Copy this skill folder, then update just the **Project configuration**
section above:
- GitLab group URL and target project path(s) — if the source file could
  plausibly cover more than one project in the group, don't guess the
  mapping; ask the user before creating anything
- The reference label snapshot (optional — it's illustrative only, since
  labels are always fetched live in Workflow step 3)

Labeling itself needs no per-project setup: it's always judged from the
target project's actual live label set, whatever that happens to be.
Everything under "Workflow" and "Key constraints" is project-agnostic and
shouldn't need changes.
