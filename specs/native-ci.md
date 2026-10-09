# Native CI

`%urgit` gains a CI system that runs GitHub Actions-style workflows without GitHub. The ship is the controller. External Linux hosts execute jobs. This document describes the design. No code in this document exists yet.

The first acceptance fixture is ERPit. Its two workflows, `suite.yml` and `fixtures.yml`, define eight jobs and use `actions/checkout@v4` and `actions/cache@v4`. The design must run those eight jobs natively before GitHub Actions is switched off for that repository.

A spike on 2026-09-12 ran all eight jobs through `nektos/act` 0.2.89 in a container with the workflows unmodified. All eight passed, including the full on-ship suite (1,586 arms) and the two-ship `duo` fixture. The same spike ran `ChristopherHX/runner.server` and found two fidelity defects in its emulated server. This document adopts `act` as the job execution engine on that evidence.

## Boundary

```text
git push / PR merge / web edit
  |
  v
%urgit
  |- refs, objects, policy (unchanged)
  |- protected-ref write gate: scry %urgit-ci before advance
  `- integration candidate materialization

%urgit-ci
  |- workflow revisions and required-workflow baseline
  |- runs, jobs, attempts, results
  |- runner enrollment and job assignment
  |- approvals, overrides, promotions
  |- credential store and CI signing key
  `- checkpoint export

runner daemon (external Linux host, one static binary)
  |
  | daemon-initiated authenticated connection
  v
%urgit-ci assignment channel
  |
  v
runner daemon
  |- connection, claim, VM lifecycle
  |- plan: `act --list` -> job list for %urgit-ci to validate
  `- execute: `act -j <job> --json` inside one disposable VM

runner daemon
  |
  | signed PUT / GET issued by %urgit-ci
  v
ship-configured object storage
  |- logs, artifacts, caches
  `- keyed by repository / run / attempt / trust class
```

## Workflow model

Workflow YAML under `.github/workflows/` is authoritative. `%urgit-ci` does not define a second workflow format. The runner daemon runs `act --list` against the checkout to produce the job list, `needs` edges, and matrix expansion. It converts that output to a bounded plan. `%urgit-ci` validates the plan's structure, limits, source identity, and requested permissions before it accepts the plan.

`act` is trusted infrastructure. It is pinned to an exact release and executes no repository script during planning. A validated plan is a translation, not a proof. The ship checks the plan's shape. It cannot check that the translation is faithful.

`%urgit-ci` evaluates job-level expressions. These are `if:` on a job, `needs.<job>.outputs.<name>`, and matrix expansion. Evaluation runs against accepted attempt state within fixed bounds. Job outputs arrive as typed `set-output` events in `act`'s `--json` stream. `act` evaluates step-level expressions inside the job. An evaluation error is an error. It never becomes `false`, `skipped`, or success.

Unsupported syntax produces a diagnosed error in the run. It is never dropped silently. `act` publishes its unsupported list. The import classifier reads it. Each imported action is classified in one of three ways: usable unchanged, needs a native equivalent, or still GitHub-dependent. `actions/cache` needs a cache service. `actions/checkout` has GitHub API fallback behavior. The import view shows the classification before the workflow is enabled. "Imported" does not mean "verified compatible".

## Execution

The runner daemon is one Go program. It holds the connection to `%urgit-ci`, claims assignments, and manages VM lifecycle. It makes no CI decisions. Inside each VM it runs `act -j <job> --json` against the exact candidate checkout. It relays the event stream to `%urgit-ci`, uploads the full log to the object store, and destroys the VM.

`act` is the job execution engine. It is pinned to one release. The daemon pins its parse of the `--json` stream to that same release. An `act` upgrade is a daemon change with a parity run, not a version bump. `act` emits step start and end, step and job results, `set-output`, `summary`, `group` and `endgroup`, and raw log lines. If `act` exits without a `jobResult` event, the daemon reports `infrastructure-error`. It never infers success from absence.

The daemon opens the connection. It authenticates, reports capacity, and waits. `%urgit-ci` selects a daemon and sends the assignment over that connection. No inbound port is required on the runner host. Dispatch authority stays on the ship. The daemon is the ship's hands. `%urgit-ci` is the controller.

Each job runs in a fresh VM booted from an approved image with resource limits. A workflow may start containers inside the VM. `act` mounts a Docker socket into the job container by default, because that is how `container:` and `services:` work. That socket belongs to the VM, never to the host. The spike also showed that `act`'s default host network mode breaks a fake ship's Ames bind. The daemon always passes an isolated network. The guest cannot reach the daemon's control socket, other Gall agents on the ship, or LAN addresses outside policy. The daemon destroys the VM after the job ends, whatever the outcome. A failed teardown marks the slot as quarantined and blocks reuse. There is no fallback to a shared host.

The daemon enforces deadlines set by `%urgit-ci`. After a restart it reconciles orphaned VMs against `%urgit-ci`'s assignment records. A stale attempt cannot overwrite a newer one.

## Trust and credentials

A revision from an untrusted source needs approval before it runs. Approval is per revision. A repository may opt in to automatic restricted checks for untrusted revisions. A restricted check receives no credentials, cannot write to a trusted cache namespace, and cannot deploy or publish. Approval to test grants no other permission.

A job that needs a deployment or publishing credential needs a separate approval by default. A repository may define automation rules for named environments. For example, staging deploys automatically and production requires a manual approval. These rules live in `%urgit-ci` policy, not in workflow YAML. A privileged job runs in a fresh VM from a trusted image. `%urgit-ci` never redeploys blindly after a lost response.

`%urgit-ci` stores third-party credentials. It releases a credential only to an authorized attempt, scoped to that attempt, for a bounded time. An external vault is optional and not required. Credential values enter pier history when they are stored. Rotation and revocation with the provider are the operator's responsibility.

A dedicated CI signing key lives in `%urgit-ci`. The ship's networking authentication key certifies the CI key. The CI key signs each credential grant and each assignment. Verifiers hold the public certificate chain only. Neither private key leaves the ship. The signature format names the recipient, the attempt, the operation, an expiry, and a nonce. A signature is authorization. It does not encrypt.

## Protected refs

Today `%urgit` enforces two rules on a protected branch. The branch cannot be deleted. Updates must be fast-forward. A pull-request merge constructs the merge commit at merge time. None of these steps tests the commit that lands.

A CI-protected branch advances in one of two ways. Either the new tip is a tested integration candidate, or an override role records an explicit override. There is no third path.

`%urgit` materializes the candidate without moving the ref. For a divergent source, the candidate is the merge of the source head onto the current destination tip. For a fast-forward, the candidate is the source head. `%urgit-ci` runs the required checks against that exact object ID. At landing, `%urgit` scries `%urgit-ci` for eligibility. It advances the ref only when the candidate is eligible under current policy and the destination tip has not changed. `%urgit` never regenerates a commit after testing. A different timestamp or message is a different commit.

A pull request with many commits is one candidate. Candidates run checks concurrently. Landing is ordered. A candidate built on an expected predecessor stays eligible when that predecessor lands as expected. If the predecessor fails or the destination moves unexpectedly, the candidate is rebuilt and retested.

Required checks come from an approved workflow revision recorded in branch policy. They do not come from the candidate's own YAML. A pull request that edits a workflow gets an unprivileged trial run of the edited workflow. Trial results do not satisfy the required checks. A maintainer with CI-policy permission promotes the new revision. Then the required checks run again against the candidate. The approved revision covers the scripts and local actions the YAML calls, not the YAML file alone. ERPit's `suite.yml` reads its structural test list from `bin/test.sh`, so that script is part of the baseline.

A direct push, web edit, or import to a CI-protected branch is never applied. `%urgit` stages the pushed head as a candidate and answers the push with `ng <ref> staged as candidate <id>`. The candidate lands through the same checks as a pull request. An override is a separate recorded action by a branch override role. The record names who, which object ID, why, and which evidence was missing. An override is never a push flag. A Clay-bound protected branch publishes to the desk only when the candidate lands.

## Storage

Logs, artifacts, and caches go to an S3-compatible object store. `%urgit-ci` reads the endpoint, bucket, region, and credentials from the ship's `%storage` agent, the same source `%urgit` uses for Git LFS. Any store that accepts Signature Version 4 requests works. There is no separate urgit setting. If `%storage` is configured, CI uses it. If `%storage` is not configured, `%urgit-ci` refuses to enable CI on any repository and reports the missing configuration.

`%urgit-ci` signs a short-lived upload URL for each attempt and a short-lived download URL for each authorized viewer. Only handles, sizes, hashes, and completion state enter Gall state. Bounded progress messages travel over the assignment channel. Full logs upload in chunks. `act`'s `--artifact-server-path` and `--cache-server-path` are the two seams where the daemon substitutes signed-URL access to the object store.

CI keys use a prefix that LFS cleanup never scans. The operator may point CI at a separate bucket. A shared bucket with the CI prefix is the default.

Keys are namespaced by repository, run, attempt, and trust class. `%urgit-ci` refuses to sign a read across trust classes. An untrusted run's cache cannot be read by a trusted run. Cache poisoning is blocked at signing time, not by runner cooperation.

A store outage yields `unknown` for the affected attempt. It never yields success. Store retention and backup are operator policy, separate from the checkpoint below.

## Recovery

`%urgit-ci` writes a checkpoint on every CI-policy change and on a configured schedule. A checkpoint contains the CI-configuration projection only:

- branch CI policy and approved workflow revisions
- environment rules and override roles
- runner enrollment records with public keys
- credential references without values
- the CI certificate chain
- bounded run summaries with store handles
- the approval and override audit
- a manifest

A checkpoint excludes repository objects, LFS payloads, store bytes, credential values, private keys, live leases and approvals, and the GitHub token. Hosted repositories are recovered by Git clone or mirror. The checkpoint does not duplicate them.

`%urgit-ci` commits each checkpoint to a private urgit repository on the ship and pushes it to an independently held clone. "Checkpoint written" and "replica confirmed" are separate records. A failed push is a failed backup.

Restore is explicit. Install the desk, import the checkpoint into a paused `%urgit-ci`, review the manifest and diff, then apply. Runners re-enroll. The recovered ship certifies a new CI key. Credential references show "needs re-entry". Old approvals and leases do not become live again. Recovery writes never trigger a workflow or a webhook.

## Packaging

`%urgit-ci` is a fourth agent in the desk beside `%urgit`, `%urgit-clay`, and `%urgit-fileserver`. Its persisted state starts at `%0`. `%urgit` changes in three places: the protected-ref gate, candidate materialization, and the staged-write handoff. `%urgit` scries `%urgit-ci` for landing eligibility. `%urgit-ci` pokes `%urgit` to materialize a candidate. Git objects never leave `%urgit`. `%urgit-ci` binds its own API base under `/apps/urgit/api` and the runner assignment channel. Both agents rebind their Eyre routes on every load.

The web interface is unchanged in shape. `%urgit-fileserver` serves the same React application. The repository page gains a CI tab for runs, run detail, and candidate status. Settings gains runner enrollment and CI-policy sections. The application calls two API bases under one origin.

The runner daemon lives at `runner/` in this repository as one Go module. `zig build` gains an optional Go step. The deliverable is one static binary, one systemd unit, one configuration file, and a pinned `act` release. The configuration names the ship URL, an enrollment token, the VM image path, and the object-store endpoint. The daemon installs on any Linux host with KVM. It may share a host with the ship or not. The object store defaults to a second unit on the same host and accepts any S3-compatible endpoint.

CI has one install prerequisite beyond the daemon. The ship's `%storage` agent must name a reachable S3-compatible endpoint with a bucket and credentials. This is a Landscape settings step. Without it, `%urgit-ci` does not enable CI.

## Cutover

Native CI runs beside GitHub Actions on ERPit for a shadow period. Both systems report on every pull request and push. A disagreement is a native-CI defect until proven otherwise. Cutover requires, in order:

1. All eight ERPit jobs run natively end to end, including the `needs.plan.outputs.replay == 'true'` gate, label and path filters, cancellation, and fake-ship cleanup.
2. N consecutive real runs agree on both systems, including a deliberate failing candidate that fails on both.
3. The full negative-test suite passes.
4. One recovery drill from a checkpoint succeeds on a disposable ship.
5. Operator documentation is complete for install, upgrade, rollback, credential rotation, retention, runner enrollment, and override.
6. The operator records explicit cutover approval.

The supported envelope is published from what the shadow period sustained. That is maximum concurrent jobs, log and artifact size limits, retention, supported guest images, supported action types, and matrix limits. No envelope number is declared from design targets.

## Repository changes

- `desk/app/urgit-ci.hoon` — new agent.
- `desk/sur/ci.hoon`, `desk/lib/ci-*.hoon` — new types and pure rules.
- `desk/desk.bill` — adds `%urgit-ci`.
- `desk/app/urgit.hoon` — protected-ref gate, candidate materialization handler, staged-write handoff.
- `desk/sur/git.hoon` — a way to mark a protected ref as CI-protected. Either `repository` gains a field or `%urgit-ci` holds the set and `%urgit` scries it.
- `fe/src/` — CI tab, Settings sections, second API base.
- `runner/` — new Go module: the daemon, plus a pinned `act` release and its `--json` parser.
- `build.zig` — optional Go step.
- `specs/architecture.md`, `README.md` — updated.

## What does not change

The Git protocol layers, object model, pack codecs, LFS, native collaboration, GitHub integration, and webhooks are untouched. Clay projection semantics are unchanged except that a CI-protected branch publishes only on landing. Unprotected branches keep Git's normal behavior. Protected branches that are not CI-protected keep today's fast-forward rule.

## Alternatives considered

- An external CI server as controller (Woodpecker, Buildbot). Rejected. The controller would live outside `%urgit`, and `%urgit` would become a webhook source.
- A GitHub Actions emulator with a server (`ChristopherHX/runner.server`). Rejected on spike evidence. The real `actions/runner` it drives is faithful. The emulated server picked `sh -e` where GitHub picks `bash -e`. It expanded `${{ runner.temp }}` in composite-action inputs to the host path instead of the container path. Both ERPit ship jobs failed on the second defect with no workflow-side fix. One maintainer, two human commits in six months.
- Self-hosted GitHub runners (`awesome-runners` list). Rejected. Every entry registers with GitHub or GHES and pulls jobs from GitHub's job service. None runs without GitHub.
- Adapt the Forgejo runner's single-job execution path. Superseded. The Forgejo runner is `act` with a Forgejo front end. Using `act` directly removes the adaptation and the fork.
- Compile workflow YAML on the ship. Rejected. The YAML and expression semantics are large, and the Hoon port becomes the bottleneck.
- Containers on the host instead of VMs. Rejected for untrusted code. It is documented as a downgrade that is never taken silently.
- An off-ship secret vault as the default. Rejected. The ship already holds `%storage` credentials. Another host adds a dependency without removing trust in the ship.
- Test the pull-request head only. Rejected. It approves an untested merge result.
- Extend `%urgit` with a new state version. Rejected. CI state and forge state have different lifecycles.
- A separate runner repository. Rejected. The ship-to-runner protocol would drift across two release trains.
- A checklist cutover without shadow mode. Rejected. Synthetic fixtures miss the timing, label, cancellation, and cleanup paths that real traffic exercises.

## Open questions for upstream

- Is a fourth agent in the desk acceptable?
- Is a Go directory in this repository acceptable? The alternative is a separate repository with the drift cost above.
- Is the change to protected-ref semantics acceptable? A CI-protected branch stages a direct push instead of applying it.
- Should CI-protection be a field on `repository` or a set held by `%urgit-ci`?
- Is depending on `nektos/act` acceptable? MIT license, 72k stars, but four human commits in the last six months. The design pins one release and assumes small patches may be carried in-tree.
- Should the ERPit workflows live in this repository as acceptance fixtures, or only a generic fixture set?
- Should `%urgit-ci` accept its own object-store configuration, or always read `%storage`? Reading `%storage` is simpler. A separate configuration lets CI use a different store than LFS and removes the dependency on Landscape settings.

## Delivery order

1. Contracts and harness: the `%urgit` to `%urgit-ci` scry and poke interface, the ship-to-runner protocol, object-store signing, and a fake-ship plus real-runner harness. Every negative test above must be able to fail.
2. Workflow model: `act --list` adapter, plan validation, job-level expressions, action classification against `act`'s unsupported list.
3. `%urgit-ci` core: runs, jobs, attempts, results, assignment.
4. Runner daemon: connection, VM lifecycle, `act` invocation and `--json` relay.
5. Trust: approvals, credential store, CI signing key.
6. Storage and web interface.
7. Protected-ref gates, shadow period, cutover.

Each step is verified before the next starts.
