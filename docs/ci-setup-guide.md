# Native CI for `%urgit`: the operator's setup guide

Your ship runs the CI. It stages every push to a protected branch as a candidate, plans the candidate's GitHub Actions workflows, hands each job to a runner daemon you install on a Linux host, keeps every log in your own object store, and advances the branch only when every job passes. Nothing here talks to GitHub.

This guide is the whole setup, in order. Every step is either a click in the ship's web interface or a command on the runner host. There is no dojo step.

The repository's **CI** tab shows a checklist of these steps, each ticked from the ship's own state, and **Set up with an agent** downloads a version of this guide filled in for your ship and repository, for a coding agent to follow. That file never contains the enrollment token.

0. [Prepare your repository](#prepare-your-repository)
1. [Object store](#1-object-store)
2. [Mint a token](#2-mint-a-token)
3. [Install the runner](#3-install-the-runner)
4. [Approve the workflows and require CI](#4-approve-the-workflows-and-require-ci)
5. [Watch](#5-watch)
6. [Runners](#6-runners)
7. [Limitations in this release](#7-limitations-in-this-release)
8. [Backup and restore](#8-backup-and-restore)
9. [Upgrade and roll back](#9-upgrade-and-roll-back)
10. [Rotate credentials and keys](#10-rotate-credentials-and-keys)
11. [Retention](#11-retention)
12. [Override a required check](#12-override-a-required-check)

## Prepare your repository

CI runs the GitHub Actions workflows in the repository's `.github/workflows/` directory. Most workflows written for GitHub run unchanged; check yours against this list.

**Supported**

- `runs-on: ubuntu-latest`, `ubuntu-22.04`, `ubuntu-24.04`, `self-hosted`, `linux`, `x64`, or a label a runner declares.
- `needs`, job outputs, job and step `if` (including `always()`, `failure()` and `needs.<job>.result`), and the common expression functions.
- Events: `push` (branches and tags), `pull_request` (`opened`, `synchronize`, `closed`, `reopened`, `labeled`, `unlabeled`), `workflow_dispatch` with typed inputs, and `schedule`, with branch, tag and path filters.
- Pull request labels. The repository owner and its writers set them on the pull request page. Each label added or removed is one `labeled` or `unlabeled` event, and a change on a closed or merged pull request runs nothing. Every pull request payload carries `pull_request.labels`, and a label event also carries `label`. A workflow runs on a label change only when its `types:` name `labeled` or `unlabeled`, as on GitHub.
- Workflow-level `concurrency`, as a group name or as `group` and `cancel-in-progress`, with expressions over `github`, `inputs` and `vars` (urgit keeps no repository variables, so `vars.<name>` reads empty). It works as on GitHub. Groups belong to the repository, span its workflows and ignore case. A new run with `cancel-in-progress: true` cancels the group's running and waiting runs. With `false`, the default, the new run waits until the run in progress finishes. A group keeps one waiting run: a newer arrival cancels the older waiting one, whatever its flag. When a run is cancelled its running jobs stop and jobs not yet started do not run, except a job whose `if` holds under `cancelled()`, such as `always()`. A running privileged job closes as unknown and needs review. The run's result is **cancelled**, which is neither a failure nor an infrastructure error, and a cancelled required run never lands. A group that cannot be evaluated refuses that workflow's run with the reason.
- `uses:` actions. They are fetched once, when you resolve dependencies (step 4), pinned in a lock and served to every job from your ship. Pin each action to a full commit SHA where you can.
- Secrets, set in **Settings → Credentials**; a job reads them as `${{ secrets.NAME }}`.

**Not supported yet: refused with the reason.** A workflow that uses one of these fails its plan or resolve with the reason. It is never run in a different way.

- `strategy.matrix`.
- Reusable workflows: `workflow_call`, and `uses:` at job level.
- `pull_request_target`, and other events not listed above.
- `concurrency` at job level (`jobs.<id>.concurrency`). Workflow-level `concurrency` is supported (above).

**Not supported yet: ignored.** Check these yourself, because no refusal shows them.

- Artifacts passed between jobs (`actions/upload-artifact` and `actions/download-artifact`). Files stay in the job's VM.
- `GITHUB_TOKEN` and the GitHub API. urgit is not GitHub. A step that calls the GitHub API fails at that step.
- Windows and macOS runners. A `runs-on` that only such a runner matches waits with the reason.

**Network.** Every job runs with no network unless you allow it. A job that downloads (`apt-get`, `curl`, a pinned binary, a package registry) needs a rule in **Settings → CI policy → Network policies**: the workflow file, the job id, a profile name and its `proto:host:port` destinations, for example `tcp:archive.ubuntu.com:80`. The runner and the launcher must allow the same destinations (step 3). Read your workflows and list the hosts each job reaches; a job that is refused network fails with the destination it tried.

**Size.** Any repository size works. A job fetches only its own commit, its history and the revision it is compared with, not every branch and tag.

## 1. Object store

CI keeps logs and artifacts in an S3-compatible object store. It reads the endpoint, bucket, region and credentials from the ship's `%storage` agent — the same settings Landscape uses for uploads and `%urgit` uses for Git LFS. Any store that accepts Signature Version 4 requests works: a bucket at a cloud provider, or a store you run yourself such as RustFS or MinIO. There is no separate CI setting. Until `%storage` is configured, the **CI required** toggle refuses with `ship object storage is not configured; CI cannot be enabled`.

**The endpoint must be reachable from every browser that will view logs, not only from the ship's host.** The ship signs a short-lived link into the store for each log, and the viewer's browser follows that link directly. A `localhost` or LAN-only endpoint works for the runner and breaks the log view for everyone else, and the symptom is `Log unavailable: NetworkError` (or `Failed to fetch`) when a log is opened. The CI tab shows the store's host with a pip: green when the browser you are using can reach it, red with the reason when it cannot.

Two things the store must allow, whichever you use:

- **Reachability from viewers.** Name the store by an address your viewers' browsers resolve and reach: a public hostname, or the LAN address of the host that runs it if every viewer is on that LAN. `127.0.0.1` is only ever right when the browser runs on the store's own host.
- **Cross-origin reads (CORS).** The web interface is served by the ship and the log by the store, so the bucket must answer CORS for `GET` and `HEAD` from the ship's origin. Without a rule the browser blocks the read and the symptom is the same `NetworkError`; the CI tab's pip then reads red with *the store refuses cross-origin reads from this page*. On RustFS and MinIO this is one bucket CORS rule (`AllowedOrigin` the ship's origin or `*`, `AllowedMethod` `GET` and `HEAD`).

On a NativePlanet box, GroundSeg fills the `%storage` settings in for you when you enable its object storage; check that the endpoint it names is one your browser reaches, not the box's own loopback.

## 2. Mint a token

In the ship's web interface open the repository, then **Settings → Runners → Mint token**. The token is shown once: paste it into the runner's config file yourself, and do not give it to anyone or to an agent.

The dialog shows the enrollment token once, beside the three config lines the daemon needs:

```toml
ship_url = "http://your-ship.example:8080"
enroll_token = "0v…"
sandbox = "microvm"
```

Copy them now. The ship keeps only a hash of the token; closing the dialog is the last time it is readable. If you lose it, **Expire** the row and mint another. A minted token that no daemon has used yet shows as `minted` in the Runners table.

The dialog also offers **Repositories this runner may take**. Leave it at *any* for a runner that takes every job (the pool), or pick repositories to make this runner run only their code. You can change this later with the **Repositories…** button on the runner's row.

## 3. Install the runner

The runner has two parts:

- **`urgit-runner`**, an unprivileged daemon that polls your ship for jobs.
- **`urgit-vm-launcher`**, a small root service that starts one throwaway Firecracker microVM per job, under Firecracker's jailer, as the unprivileged user `urgit-vm`. It is the only part that runs as root.

There is no prebuilt download in this release: build both from the urgit source that matches the desk your ship runs.

**Get the source.** The runner has its own repository: `git clone https://github.com/wundrellama/urgit-runner.git`. Use the runner commit that matches the urgit commit your ship runs. The runner's `URGIT_COMMIT` file names the urgit commit each runner commit was tested against. A runner from another version refuses the ship's assignments.

**The host.** Linux x86_64 with KVM (`/dev/kvm`), cgroup v2 (`stat -fc %T /sys/fs/cgroup` prints `cgroup2fs`), systemd, Git, outbound HTTP(S) to the ship, Go 1.27 or later to build, and about 25 GiB of disk per concurrent job. It may be the ship's own host.

**Build.**

```text
cd urgit-runner
CGO_ENABLED=0 go build -trimpath -o urgit-runner ./cmd/urgit-runner
CGO_ENABLED=0 go build -trimpath -o urgit-vm-launcher ./cmd/urgit-vm-launcher
```

The guest image (the kernel and root filesystem every job VM boots) is built by `guest/build.sh` from the recipes under [`guest`](https://github.com/wundrellama/urgit-runner/blob/master/guest). The launcher verifies the image's digests before every boot.

**Install the launcher (as root).**

1. Create the system user `urgit-vm`.
2. Create the launcher's protected root, owned by root, with `bin/`, `images/`, `jail/` and `state/` inside it.
3. Put `urgit-vm-launcher`, and Firecracker and jailer v1.17.0, in `bin/`. The launcher checks the two Firecracker binaries against the SHA-256 pins in its config at start. Put the guest image in `images/<manifest sha256>/`.
4. Write the launcher's config, mode 0600, from [`launcher/urgit-vm-launcher.toml.example`](https://github.com/wundrellama/urgit-runner/blob/master/launcher/urgit-vm-launcher.toml.example). `socket`, `socket_group` and `runner_uids` name the user the runner runs as. `ceiling` lists every network destination any job may ever reach; empty means no job gets network.
5. Install [`launcher/urgit-vm-launcher.service`](https://github.com/wundrellama/urgit-runner/blob/master/launcher/urgit-vm-launcher.service) with your paths and start it. It is not enabled at boot by default; start it after a reboot, or enable it.

**Configure and start the runner.** Copy [`urgit-runner.toml.example`](https://github.com/wundrellama/urgit-runner/blob/master/urgit-runner.toml.example) to `/etc/urgit-runner.toml`, mode 0600, and set:

| Key | Meaning |
|---|---|
| `ship_url` | The ship's HTTP origin, from the mint dialog. |
| `enroll_token` | From the mint dialog. Consumed on the first start; remove it from the file afterwards. |
| `sandbox` | `microvm`, the default. (`docker-rootless` is a trusted-compatibility profile, a container rather than a VM; see §7.) |
| `launcher_socket` | The launcher's `socket`. |
| `image_path` | The guest image directory. |
| `resolver` | `true` lets this runner resolve dependencies (step 4). |
| `capacity` | Concurrent jobs this runner offers. Default 1. |
| `cpus`, `memory_mib`, `disk_mib` | Each job VM's size. Defaults 2, 4096, 20480. |
| `budget_cpus`, `budget_memory_mib` | This runner's total, refused if the host cannot honour it. |
| `labels` | Labels matched against a job's `runs-on` (§6). Default none. |
| `[[network_profiles]]` | For each profile name your network policies use, the destinations this runner allows. |
| `work_dir`, `state_file` | Where checkouts and the runner's identity live. |

[`urgit-runner.service`](https://github.com/wundrellama/urgit-runner/blob/master/urgit-runner.service) is a `Type=simple` unit running as an unprivileged user that can reach the launcher's socket. On its first start the runner enrolls with the token, writes its identity to `state_file`, and forgets the token; its row in **Settings → Runners** flips from `minted` to `healthy` with no page refresh, and its log prints `sandbox: microvm`. Then choose **Repositories…** on its row if it should take only some repositories.

## 4. Approve the workflows and require CI

**Approve the workflows.** Required checks run the workflow files of a revision you approved, not whatever a push brings. In **Settings → CI policy**, enter the branch tip's commit and click **Resolve dependencies**: a runner fetches the actions and downloads the workflows use and records them in a lock. When the lock appears, click **Promote as baseline** for the branch. A branch with no promoted baseline waits with that reason. Change the workflows later by pushing, then resolving and promoting the new revision.

**Try it.** **CI tab → Run workflow** runs a workflow with `workflow_dispatch` by hand. A manual run never lands anything; check every job passes before you require CI.

**Require CI.** In **Settings → CI-required branches**, click **Add branch** and pick the branch. Protect it from force-pushes too, in **Settings → Protected branches**.

From then on a push or a web merge to that branch is never applied directly. The ship stages the pushed head as a candidate — the push answers `staged as ci candidate <id>` — plans its workflows, runs every job, and advances the branch to the candidate's exact commit only when every job passes. A candidate whose branch moved meanwhile is refused with `destination moved; rebase and push again`. A revision from a ship that cannot write the repository (a fork pull request) is untrusted: it waits for a writer's approval on the CI tab, or runs as a restricted check with no credentials if you choose that policy in Settings → Untrusted revisions.

The toggle refuses a branch with no commit yet (`ref has no tip; push a commit before CI-protecting it`) and any repository while `%storage` is unset. A repository bound to a Clay desk may be CI-protected: its candidate lands through the desk — the candidate's files are written to the desk first, exactly as a push to the linked branch is (so the repository must be desk-shaped: `sys.kelvin`, a mark for every file it carries, and the marks those marks build on), and the branch advances only once the desk took them and the checks still hold. When you turn it on, the CI tab's storage check runs; a red result is a warning under the toggle, not a refusal — the runner may still reach the store even when your browser does not.

## 5. Watch

The repository's **CI** tab lists candidates newest first and updates as the ship works: staged, planned, each job's attempt as it starts and finishes, the verdict, the landing. The pip beside the store's host reads `live` while the tab is subscribed to the ship; if the connection drops it reads `polling`, the list re-reads every ten seconds, and **Refresh** reads it now.

Open a candidate for its jobs: each row shows the job, its `runs-on`, the runner that ran it, timing, and a **log** link once the log is in the store. **Approve and run trusted** appears on an untrusted candidate (the tooltip names the repository's policy); **Re-run** stages the same head again.

The run's **Concurrency** panel shows each workflow's group and its state in plain words: *in progress in group deploy-main*, *waiting for run push of 1a2b3c4d to main in group deploy-main*, *cancelled: the newer run (push of 5e6f7a8b to main) joined group deploy-main with cancel-in-progress*, or a refusal with its reason. Runs are named by their event and source. Their ids are in the fine print. A run waiting in its group is tagged in the list. **Cancel run** cancels every workflow of the run that has not finished. A workflow's own **Cancel** stops only that workflow's jobs. Both use the same path as a concurrency group cancellation, and both ask first. Only the owner and a ship with the repository's `ci-policy` role see them. The ship refuses anyone else, and the page shows the refusal as the ship words it.

A run whose lock was resolved before concurrency was read says *concurrency not read for this lock: resolve or promote again to apply it*, and takes part in no group until the revision is resolved and promoted again. That is unknown, not "no group". A run already in flight when the ship upgraded takes part in no group, and its page says so.

Until CI is set up the CI tab shows the setup checklist, each step ticked from the ship's state, with this guide and the agent file one click away. Once every step is done it folds to one line.

## 6. Runners

**Settings → Runners** lists every daemon record: id, capacity, sandbox, labels, repositories, enrolled and last-seen ages, running jobs, and a state:

- `minted` — a token exists; no daemon has enrolled with it. **Expire** deletes it.
- `healthy` — seen within the last five minutes. The daemon polls even while it is busy at capacity, so this is liveness.
- `stale` — not seen for five minutes. The ship hands it nothing; any assignment it never fetched is offered to another runner. It reads `healthy` again at its next poll.
- `refused` — it abandoned an assignment because the assignment did not verify against the CI public key it pinned at enrollment (after **Rotate CI key**, or a wrong key in its config). It is offered no work until it re-enrolls; ordinary polls do not restore it. Recovery: stop it, delete its state file, mint a new token, start it. Then **Revoke** and **Remove** the old row. First check its **Retentions**: deleting the state file discards them (below).
- `revoked` — you revoked it. Its next poll was refused, it logged `revoked by the ship` and exited with status 5; every job it was running was offered to another runner. **Remove** deletes the row.

**Revoke** ends a runner's access at once: the bearer is cleared, its next poll answers 401, and a job it was running is re-offered. "Regenerate" is revoke (or expire) plus mint: two clicks.

**Rotate CI key** replaces the key the ship signs every assignment with. Every enrolled runner pinned the old key, so each one refuses its next assignment, shows as `refused`, and takes no work until you re-enroll it with a fresh token. Jobs already running finish.

**Labels.** A runner declares labels in its config, `labels = ["big-mem", "arm64"]`, and sends them on every poll. A job runs on a runner only when every label in its `runs-on` is one the runner declares or one of the implicit set every runner stands for: `self-hosted`, `linux`, `ubuntu-latest`, `ubuntu-22.04`, `ubuntu-24.04`, `x64`. So `runs-on: ubuntu-latest` runs anywhere, and `runs-on: [self-hosted, big-mem]` runs only on a runner that declared `big-mem`. A job no runner can take waits, and the candidate row says why: `no runner has labels [big-mem]`; it runs as soon as such a runner enrolls. `runs-on` is matched as literal labels; an expression there is refused at plan time.

**Repository binding.** The table's **Repositories** column is set on the ship — in the table, or in the mint dialog — never in the daemon's config: the machine does not get to declare which code it may run. *Any* is the pool. *Only …* restricts the runner to the named repositories; the ship never hands it a job of any other. The binding is ship state and survives the daemon's restart. This is how you keep one runner that only ever executes trusted code from named repositories while another takes everything, including fork pull requests run as restricted checks.

**When a runner dies mid-job.** A job whose runner gives up is offered to another runner at once; if no other runner exists the candidate fails with the runner's reason. A job whose runner goes silent — no result by the job's `timeout-minutes` plus two minutes (an hour when the job declares none) — is offered again once to another runner, and fails as `runner went silent` if that runner goes silent too. A late result from the first runner is refused as `attempt is closed`.

**An assignment delivered again.** The ship may hand an assignment over again while its job runs or waits here: after a lost reply, or as a copy, however its attempt id is written. The runner ignores it and says nothing about it to the ship, so the job is never offered to another runner while it runs here. The runner names every attempt as the ship writes it.

**An assignment runs at most once on a runner.** The runner records each attempt it takes in its execution ledger, `executions/` beside the state file, before anything of the job runs, and again when the job ends. A copy of a finished job's assignment is ignored. A copy of a job that a stop cut short is given back to the ship, which offers the job again as a new attempt, or closes it. If the ledger cannot be written (a full disk, a permissions change), new assignments are given back, not started, and nothing is deleted to make room. The ledger grows by two small files per attempt and is kept: nothing prunes it, and nothing in it may be deleted. The state file names it, and a start that finds the ledger gone, or missing `taken/` or `finished/`, is refused. Back it up, and restore it, together with the state file.

**Upgrading from a runner without the ledger.** What the earlier version ran left no record, so the upgraded runner runs nothing until you confirm its transition. At its first start it logs `EXECUTION PAUSED`, polls advertising no capacity, and gives back every assignment it receives. It still reports its retentions and carries out their release. In **Settings → Runners** it is marked *execution paused*: open **Transition…**, inspect its history and the proof, and confirm. The runner checks the transition, records it, and from then on refuses every assignment the ship signed before it, and runs new work. Nothing is released, reset or re-enrolled, and there is no drain or wait. A runner whose `executions/HISTORY` cannot be read waits the same way. So does one whose state file's `transition` is damaged, not a record this version wrote: it keeps the record as it is, says why in the panel, and waits for its transition to be confirmed again. A state file that names a field twice, which no runner writes, refuses the start and is left as it is. The ship must run this version too (QUESTIONS-SOURCE-01 §15; [`launcher/INTEGRATION.md`](https://github.com/wundrellama/urgit-runner/blob/master/launcher/INTEGRATION.md) §11.15).

**Quarantined slots.** When a sandbox's release cannot be proven — a VM the launcher could not stop or clean up in time, a container whose removal failed — the daemon withholds that slot (it offers the ship one fewer), records it in its state file under the sandbox's exact identity and its job's name, and logs `QUARANTINED slot ci-<attempt> …`. Cleanup may still run automatically and stop or remove what is provably that sandbox's, but nothing releases the slot by itself — not even a cleanup that finally succeeds after its deadline — and a restart never charges it twice. Cleanup and release are separate steps, each yours:

1. **A VM: the launcher's incident first.** As root, stop the launcher's `serve`, then run `urgit-vm-launcher recover -config /etc/urgit-vm-launcher-p4-opus.toml`. It lists the incidents by job (repository · workflow · job), each with its exact reservation (id and incarnation token; cid, created), whether its cleanup deadline was missed, what it still holds and the capacity it withholds. Pick one by its number to see its inspection: every cleanup attempt, what was stopped or removed and what is unresolved, and why release is refused or allowed. `r` retries its cleanup; that never releases it. `R` releases it once nothing is held, after you type `release`. A VM whose pid was never recorded is looked for by the retry, and stopped if found; a release is never taken as proof that it is gone. Scripts use `-select <id>/<incarnation>/<cid>/<created>/<rev> -action inspect|retry|release`, with the same checks (the incarnation is `-` for a reservation written before incarnation tokens). Start `serve` again.
2. **The daemon's retention.** Stop the daemon (the launcher's `serve` running: the runner asks it), then run `urgit-runner -config /etc/urgit-runner.toml -recover`. It lists the retentions the same way. A VM's slot is released only on the launcher's evidence of that exact reservation's release. A reserve request whose outcome the daemon never learnt (listed as `reserve request <token>, its outcome not settled`) is released only on the launcher's settlement of exactly that request: allowed when the launcher never admitted it and has closed it for good, or proves the release of what it admitted; refused when it admitted a reservation — the output names it, and it follows its own disposition. An empty list is never enough. Its inspection only reads; a retry has nothing to clean up. An older retention that a daemon before settled admission recorded without its reserve request (a *legacy* retention, listed with `legacy: released from Urgit`) is never released by `-recover`: it is released from Urgit, by the running daemon (below). One that names only its handle, from before retentions named their backend, stays withheld (QUESTIONS-SOURCE-01 §11). A container's objects can be removed from here (`r`, by their exact names; it stays retained), and it is released only when Docker answers, at the moment you release it, that none of them exists — its exact not-found reply about each object; any other answer refuses the release. Scripts use `-recover -select <selection> -action inspect|retry|release` (the selection is shown by the inspection): exit status 0 done; 1 refused or unresolved (the output says why); 2 the daemon is running, or the state file could not be read or saved — run it again.
3. **Start the daemon**: the slot is offered again.

Listing and inspecting work while the daemon and the launcher run. A retry or a release takes the lock of the process it acts for, so that process is stopped first: the launcher's `serve` for `urgit-vm-launcher recover`, the daemon for `urgit-runner -recover`, whose release of a VM's slot asks the running launcher. A released incident is kept as evidence: the launcher keeps it under `released/` in its state directory, and the daemon keeps it in its state file's `released` list.

**Reserve requests whose answer was lost.** Before the daemon asks the launcher for a VM, it records the request in its state file; if it cannot, it sends none. If the answer never arrives, or the launcher refuses, the daemon has the launcher settle exactly that request before it offers the slot again. The launcher either names the VM it admitted — the daemon then destroys or holds it like any leftover — or closes the request for good, so that a delayed or replayed copy of it can never be admitted later. Until then the slot stays withheld and the daemon logs `ADMISSION NOT SETTLED`. Every reconcile asks again — at each start, before any job, and every 30 seconds while it runs — and the slot returns by itself once the request is settled; nothing is yours to do. The launcher keeps one small file per request under `requests/` in its state directory and never deletes them (QUESTIONS-SOURCE-01 §10).

**Legacy retentions, from Urgit.** A runner before settled admission could record a retention with neither the launcher's identity of its reservation nor its reserve request (its reserve's answer lost while the launcher could not be asked). Nothing can settle such an entry by its request. This release marks it *legacy* when it first loads that state file, and saves the file in its own format, so no entry it writes itself is ever marked. It is released from **Settings → Runners → Retentions**:
1. The running daemon reports every retention to the ship, with how its slot returns. For a legacy one it also reports its evidence: the launcher asked (its version and protocol), whether the launcher's inventory is authoritative, and what it holds of the attempt.
2. Select the runner's **Retentions** and inspect the legacy one. A release is offered only when every condition holds:
   - it is legacy;
   - it is a launcher reservation;
   - the launcher speaks protocol 4, which refuses every reserve that names no request token — the only kind this entry's request could be;
   - its inventory is authoritative;
   - it holds no record of the attempt, in any state;
   - the attempt is not running here.
3. **Release this retention…** restates the exact entry, revision and evidence. Tick the acknowledgment, then release. The ship records a command for exactly that entry, revision and evidence. It signs the command for this daemon and hands it over on the daemon's own poll, within about 25 seconds.
4. The daemon checks everything again when the command runs. It refuses if anything changed, or if the command expired (fifteen minutes). Otherwise it saves the release in its state file, with the command and the evidence. The slot returns only once that save is durable.

The panel shows the command as one of:
- *queued*;
- *pending*;
- *released*;
- *refused*, with the reason: the slot stays withheld;
- *uncertain*: no final answer is recorded yet. A save's outcome is unknown, a refusal is not recorded yet, or the daemon cannot authenticate the command. The slot stays withheld, the daemon takes no new work while its state file is not durable, and the ship hands the command over again;
- *expired*.

The daemon records every release and every refusal in its state file before it answers. A lost reply, a command handed over again, however its id is written, or a daemon restart is answered from that record. Nothing is released twice, and a refused command is never carried out later. To try again after a refusal, confirm the release again: that is a new command.

Nothing at the launcher is touched. A record of the attempt there refuses the release; that reservation follows its own disposition. A daemon whose every slot is withheld keeps running while one of them is a legacy retention, so the command can reach it.

**Re-enrolling a runner that withholds slots.** Re-enrolling today means deleting the state file, which discards every retention it holds — real quarantines included — and returns their slots without proof. Do not delete the state file of a runner whose **Retentions** lists anything.

**Upgrading the ship.** An upgrade of `%urgit-ci` keeps its state, and with it every runner's enrollment and bearer (contract §8c). A runner goes on polling, and needs no re-enrollment. Its state file, with its retentions and recorded refusals, is never touched by the ship's upgrade. Do not nuke `%urgit-ci` to upgrade it: a nuke forgets every runner. This release has one persisted state. A saved state of another shape is refused, not reset.

**Late bookkeeping.** A sandbox whose cleanup finished before its deadline is released once the launcher has kept its evidence and durably withdrawn its record — even if that withdrawal is confirmed after the deadline, which is then said apart: serve logs `RELEASED, ACCOUNTING CONFIRMED LATE`, the evidence under `released/` records it, and `urgit-vm-launcher list` reports every such release. Until the withdrawal is confirmed the slot stays charged. The launcher keeps that evidence only in a real `released/` directory in its state directory, and certifies the directory's link at every release: if the state directory's fsync fails, or `released/` is not a directory, every release stays charged until it is repaired, and `urgit-vm-launcher list` reports a `released/` that is not a directory as unreadable evidence. `urgit-runner -recover` releases a VM's slot only on the launcher's evidence of that exact reservation's release: a reservation the launcher no longer holds, gone without evidence, is never taken for released.

**The launcher's unaccounted entries.** If the launcher's `serve` logs `UNSAFE STATE` — an entry in its records directory it cannot read or does not recognize — it keeps enforcing the reservations it could read, but admits nothing and treats no absence as a release until you resolve the entry by hand, with `serve` stopped, and start it again. Until then, `recover` shows no incident as released, `urgit-runner -recover` refuses a VM's release, and the daemon frees no slot. A daemon that starts meanwhile logs `the sandbox backend's records could not be reconciled` and exits with status 2. No enrollment was lost, so do not re-enroll. The entry is never deleted for you.

**State file not writable.** If the daemon cannot save a quarantine to its state file (a full disk, a permissions change), it logs `STATE NOT DURABLE`, keeps the slot withheld, keeps polling and finishing the work it runs, and answers every new assignment `runner state not durable`, so the ship offers it elsewhere, until a save succeeds.

## 7. Limitations in this release

- `microvm` (Firecracker + jailer) is the default backend and the one every privileged, trial, shadow and untrusted job needs; it requires the administrator-owned `urgit-vm-launcher` and a digest-verified guest image, and refuses to start without them — it never falls back to a container. `docker-rootless` remains for trusted compatibility work on a repository that opted in explicitly (`set-sandbox-requirement container`): its sandboxes are containers, not a VM boundary, and a network profile there is NAT egress as a whole rather than the launcher's per-destination enforcement.
- Execution is locked by default: no egress at all unless the repository's policy authorizes a profile for that job and the runner declares it.
- The VM path's image, kernel, guest helper and protocol are built from the recipes under [`guest`](https://github.com/wundrellama/urgit-runner/blob/master/guest) and proven by unjailed preflight boots; the jailed path — the launcher, its cgroups and its network policy — waits on the administrator's review of the launcher recipe and is not claimed qualified here.
- The promoted baseline's workflow and harness bytes are the required evidence, not the candidate's own. A candidate whose harness differs runs a trial beside the required run — unprivileged and never landable — and a branch with no promoted baseline waits with that reason.
- The web interface's **Approve** button is the owner's. A listed writer on another ship approves through the peer protocol from their own ship (`POST /peer/ci-approve` with the owner ship, the repository and the candidate id; the answer arrives as a forge request of kind `candidate`); the owner's ship admits exactly the ships that can write the repository. No button for it yet.
- Retrying or releasing a quarantined slot needs the daemon stopped, and for a VM the launcher's `serve` stopped for its own retry and release first (§6), which tears down every VM that launcher runs: there is no live administration channel. The one exception is a legacy retention, released from Urgit through the daemon's own poll (§6). No host listener is added for it.
- The checkout authenticates with a read capability the ship issues for that attempt alone, so private repositories work; the runner never stores it.
- A credential value is at least eight characters and may span lines (a PEM key pastes as is). `act` masks a secret only where the whole value appears on one output line, so the runner and the ship scrub every released value whole and every line of it of at least eight characters from the relayed stream, the saved log and the recorded outputs.
- The CI public key is pinned at enrollment. A rotated key needs a fresh enrollment (or `ci_public_key` in the config, for testing only).
- A matrix strategy and a `runs-on` expression fail the plan with a diagnosed reason; a manual workflow using one is listed in Run workflow as unable to run, with that reason.
- **Automatic events** (Delivery 1C): pushes, native pull request activities and schedules run the workflows that the promoted baseline's `on:` selects. The native activities are `opened`, `closed`, `reopened`, `synchronize`, `labeled` and `unlabeled`. A revision resolved by an earlier runner has no trigger definitions, so resolve and promote it again with this release's runner. The resolver posts the compiled catalog beside the lock (`triggers`). The daemon runs each admitted job on its signed event, as `act pull_request …` or `act schedule …` with `-e /work/event.json`. For a pull request, act derives `github.ref` as `refs/pull/<n>/merge` from the payload's number. It takes `github.sha` from the checkout, which is the merge the ship built. For a schedule, `github.ref` comes from `repository.default_branch`. The daemon refuses a job whose signed `trigger` does not begin with its event. It also refuses a pull request payload whose number, head or target do not match, or whose labels are malformed. It refuses a schedule payload whose default branch is not the signed ref. Event runs never land, receive no credentials and always run in a VM. Not supported: `pull_request_target`, other activity types and events (diagnosed, never run as a push), and a deletion's `delete` event. Schedules beyond 2040-01-01 refuse until re-resolved with a newer compiler.
- **Manual runs** (CI tab → **Run workflow**): a workflow that declares `on.workflow_dispatch` at a branch's promoted baseline runs on that branch's tip with its declared inputs (boolean, number, choice, string, environment), checked by the ship. The list is the resolver's: resolve and promote a revision with this release's runner to list its manual workflows. A manual run never lands, receives no credentials (an environment input only names an environment), is not re-run in place, and is cancelled if the policy generation moves while it is open. A job-level `if` on `inputs` is not supported yet.
- The saved `act` stream is uploaded as `log.jsonl`. Step summaries and artifacts stay in the sandbox and are not uploaded.
- **Concurrency**: a job stopped by a cancellation stops whole. A step with `if: always()` (or `cancelled()`) inside it does not run, because its sandbox is stopped. A job-level `if: always()` does run. Job-level `concurrency` is refused.
- The store's `public-url-base` setting is not read: the endpoint `%storage` names is the one both the runner and every browser must reach.

## 8. Backup and restore

Your ship writes a checkpoint of its CI configuration whenever that configuration changes. You can also write one at any time with **Settings → CI recovery → Checkpoint now**.

A checkpoint holds the CI configuration only:

- each repository's CI policy, its promoted baselines and the locks they name
- environment rules, role bindings and override roles
- runner records: id, labels, repository binding, and enrolled and revoked times
- credential references: repository, name, scope and environments, never a value
- the CI signing public key and its certificate, never a private key
- the newest 100 run summaries, with their log handles in your object store
- the approval and override audit, as history

A checkpoint never holds any of these:

- a repository object, an LFS payload or store bytes
- a credential value or a private key
- a bearer or token hash, a mirror token or a read capability
- a live lease or an approval in force
- the GitHub token

Back up your repositories themselves with `git clone --mirror`.

### Where checkpoints go

The ship commits each checkpoint to its private repository `ci-checkpoints`. The first checkpoint creates that repository. Each commit holds the newest checkpoint under `checkpoint/`, and Git history holds every earlier one. `checkpoint/manifest.json` lists each file with its byte length and its sha-256.

A copy on the same ship is no backup. After each write, the ship pushes `ci-checkpoints` to that repository's own origin, its replica. Set one up before the first checkpoint, in one of these two ways.

- **GitHub.** Create a private GitHub repository with one commit, and connect a GitHub token in **Settings**. Then import that repository into urgit under the name `ci-checkpoints`.
- **Another ship you control.** Create a repository with one commit on that ship, and make this ship a writer of it. Then fork it to this ship under the name `ci-checkpoints`.

With neither, the ship cannot push, and it says so. Hold a copy yourself instead:

```sh
git clone https://<your-ship>/git/ci-checkpoints.git
cd ci-checkpoints && git pull
```

Run `git pull` again after every checkpoint.

**Settings → CI recovery** shows the last checkpoint as two separate facts:

- **Checkpoint: Written** means the commit is in `ci-checkpoints`.
- **Backup: Replica confirmed** means the replica accepted the push. This is the only state that is a backup.
- **Backup failed** and **Replica not confirmed** mean the replica does not hold this checkpoint. Fix the replica, then press **Checkpoint now**.

### The restore drill

Run the drill on a fresh, disposable ship first. Each step below is one action.

1. Install the urgit desk on the ship.
2. In **Settings → CI recovery**, press **Pause CI**. While CI is paused it admits no run, offers no runner work, admits no scheduled run and lands nothing.
3. Create each repository on the ship, and push it from its own Git replica with `git push --mirror`. Do this before the apply, because the apply skips a CI-protected branch that has no commit yet.
4. Create a private repository named `ci-checkpoints`. Push your replica's branch into it: `git push https://<ship>/git/ci-checkpoints.git main`.
5. Press **Import**. Leave the commit empty to import the newest checkpoint. To import an older one, enter its commit from `git log`. A corrupt, truncated or unsupported checkpoint is refused whole, with the reason.
6. Read the staged checkpoint's manifest and its diff. Each role grant it adds is a line of its own.
7. Press **Apply…**, tick the box, and press **Apply**. The apply waits until no attempt is running.
8. Re-enter each credential listed under **Credentials to re-enter**, in its repository's settings.
9. Mint a new token for each runner listed under **Runners to re-enroll**, and enroll that runner again.
10. If a default branch runs workflows on a schedule, promote its baseline again. An apply arms no schedule.
11. Press **Resume CI**. Resuming starts no run and lands nothing. The next push, pull request or dispatch runs under the restored configuration.
12. Press **Checkpoint now**, so that the replica holds the restored configuration. No checkpoint is written automatically while CI is paused.

An apply never rewinds authority:

- A credential comes back as a name that needs re-entry, with no value.
- Approvals and overrides come back as inert history only.
- Runners come back as records that must re-enroll, with no bearer.
- The ship keeps its own new CI signing key. The old public key is kept as history.
- Run summaries come back as history, and none of them can land anything.

## 9. Upgrade and roll back

**Before an upgrade.** Do these steps before you install a new version of the desk or the runner:

1. Press **Settings → CI recovery → Checkpoint now**, and make sure the checkpoint reads *written*.
2. Clone each repository with `git clone --mirror`.
3. Clone the `ci-checkpoints` repository.
4. Keep the previous `urgit-runner` binary and the previous desk commit.

A copy of the pier is not a backup. Do not use one as a rollback.

**Upgrade the ship.** Install the new desk. `%urgit-ci` loads its saved state as it is. A later release that changes the state converts it on load and writes a `state-migration` entry in the audit. Runners keep their enrollment and do not need a restart. Do not nuke `%urgit-ci` to upgrade it: a nuke forgets every runner, credential and policy.

**Upgrade a runner.** Stop the runner, replace the binary, and start it again. Keep its state file and its `executions/` ledger. A runner that comes from a version without the ledger pauses until you confirm its transition (§6).

**Roll back.** There is no downgrade of saved state. An older `%urgit-ci` refuses a state from a newer version. It does not reset the state, and it does not run with it. A rollback is possible only across releases that did not change the state version. In that case, install the previous desk commit. Across a state change, keep the newer version and fix forward. If the ship itself is lost, restore onto a fresh ship as §8 describes.

A runner downgrade is not qualified. Keep the previous binary for a fix-forward comparison, not as a rollback.

## 10. Rotate credentials and keys

**A credential value.** In **Settings → Credentials**, enter the same name with the new value. The new value replaces the old one. Jobs that start after the change get the new value. A job that is already running keeps the value it was given, until its deadline. To remove a credential, press its delete button. The ship never shows a stored value.

**The CI signing key.** Press **Settings → Runners → Rotate CI key**. Then do these steps for each enrolled runner:

1. Wait for the runner to show `refused`. Jobs that were running finish first.
2. Check its **Retentions**. Do not continue while it lists anything (§6).
3. Stop the runner.
4. Delete its state file.
5. Mint a new token, and put it in the runner's config as `enroll_token`.
6. Start the runner. It enrolls again and pins the new key.
7. **Revoke** and **Remove** the old row.

**A runner's bearer.** **Revoke** the runner, then mint a token and enroll it again as above. A revoked bearer gets HTTP 401 at its next poll.

**The object store credentials.** Change them in the ship's `%storage` settings. The ship reads `%storage` each time it signs a request, so the next upload and the next log link use the new credentials. A log link that the ship signed before the change expires within five minutes.

## 11. Retention

CI deletes nothing on its own. Plan for these:

- **Logs in the object store.** Every job log stays under the `ci/` prefix of the bucket. Set a lifecycle rule on that prefix if you want logs to expire. A run whose log was deleted keeps its verdict. Its log link then answers with the store's error.
- **Run records on the ship.** Every run and its attempts stay in `%urgit-ci`. Deleting a repository deletes its CI records.
- **Job streams on the runner host.** The runner keeps each job's `<attempt>.act.jsonl` in its `work_dir` after it uploads the stream. You can delete the stream of an attempt that the ship shows as finished.
- **The runner's execution ledger.** `executions/` grows by two small files per job and must not be pruned (§6).
- **Checkpoints.** Each checkpoint is one commit in `ci-checkpoints`, and it holds at most the newest 100 run summaries.

## 12. Override a required check

An override lands one exact candidate without the evidence it is missing. Use it only for an emergency.

1. In **Settings → CI policy → Roles**, bind the `override` role for the branch to the ships that may override. The owner holds the role always.
2. Open the candidate on the **CI** tab. The **Override** block shows only for a required candidate that has not landed.
3. Write the reason. The ship records the reason, your ship and what was missing.
4. Press **Record override and land**, and confirm.

The ship refuses an override in these cases:

- CI is paused.
- The candidate is not built yet.
- The candidate is a trial or a shadow run.
- The branch has moved since you opened the candidate.

An override is valid for fifteen minutes. A change of CI policy cancels an override that was not used. The candidate's own status does not change. The audit and the candidate both show the override.

## How it works

The daemon enrolls once, then long-polls the ship for assignments; the poll is also its heartbeat. A plan assignment means: check out the candidate, run `act -l` on every workflow file, and post the job list with each job's `needs`, compiled `if`, `environment`, `runs-on` and `timeout-minutes`. A job assignment means: check out the candidate, write a single-job projection of its workflow, and run act on it inside a fresh sandbox for the event the ship signed, on the payload the signed context binds: `act push -j <job> -e /work/event.json --actor <ship> --json` for a push (its ref, base, source and pusher), `act workflow_dispatch -j <job> -e /work/event.json --actor <ship> --json` for a manual run (its typed inputs). The daemon relays every event line and claims the `jobResult` the stream carried; when `act` exits without one, it abandons the attempt with the reason. It never infers success.

Every assignment carries the ship's signature over the recipient, the attempt, the operation, an expiry and a nonce; the daemon verifies it with the CI public key it pinned at enrollment and refuses an unsigned or bad-signed assignment before any work. A trusted job's assignment also carries grants: the credentials the ship released to that attempt, each signed and bounded by the attempt's deadline, each passed to `act` as a secret.

After `act` exits the daemon uploads the saved stream to the object store under a ship-signed PUT, then posts the result naming the object's size and hash. A viewer reads the log through the ship, which answers a presigned link into the attempt's own trust class.

If the upload fails, the result names no log. The ship then records a passed or skipped job as an infrastructure error, and the run reads as unknown. A store outage never gives a green run. A failed job stays failed. Fix the store, then run the job again.

Every attempt gets its own Docker network, work volume and runner container on the rootless daemon. The checkout enters the container by copy, never by bind mount; the rootless socket is the only mount, and `act` is told to bind that same socket into each job container, so the job's Docker is the rootless daemon by construction. The daemon destroys the sandbox after every attempt; a failed teardown quarantines that slot and lowers the advertised capacity. After a restart the daemon asks the ship about each leftover sandbox and destroys every one whose attempt is closed or unknown; it never resumes a job.

`act -j <job>` would run the job's whole prerequisite chain and evaluate job-level `if` itself; the ship owns admission, so the daemon runs `act` on a projection of the workflow holding only the assigned job, with its `needs` and job-level `if` removed and the job's `name:` replaced by `<attempt>/<its name or id>`: act names a job's containers, volumes and services network from `<workflow name>/<run name>`, so two attempts on one job never share them, while the workflow keeps its own `name:` (`github.workflow`) and the job its id (`github.job`). A job written as a flow mapping (`job: {…}`) is refused. The ship refuses any relayed event whose job is not the assigned one.

A job reads its prerequisites through GitHub's own `needs` context: `${{ needs.<job>.outputs.<name> }}` and `${{ needs.<job>.result }}` in step conditions, `run:`, `env:` and `with:`, unchanged in the YAML (Delivery 1B). act builds `needs` only from upstream jobs of the same run, and the projection holds none, so the projection rewrites every `needs` root in the job's expressions to `fromJSON(vars.URGIT_NEEDS)` and the daemon passes `--var URGIT_NEEDS=<context>`: the context the signed manifest binds, verified on arrival. String literals, property names and every other context are left as written; the values travel as data, never spliced into expression or shell text. A job that reads `needs` is re-encoded from its YAML tree with only those expressions changed and decoded again before use; a job that does not keeps the byte-for-byte cut. Limits: `toJSON(vars)` shows the carrier; an expression that reads `needs` but cannot be read refuses the projection; the job-level `if` is the ship's and never reaches act.

The daemon prints its sandbox disclosure at startup. A compatibility daemon prints `sandbox: docker-rootless (container compatibility mode; not a VM boundary; a network profile is NAT egress as a whole, destinations not narrowed)`; a VM daemon prints `sandbox: microvm (Firecracker + jailer; one disposable VM per attempt via urgit-vm-launcher; image <digest>)` followed by its guest and budget numbers.

### Automatic dependency inputs

Ordinary tags use the YAML at their captured commit. In repository Settings → CI policy → **Automatic dependency inputs**, the owner or a CI policy delegate may add or remove exact public HTTPS source URLs. The initial list is empty. A permission applies across tags, without a separate approval per tag. Edits use the generation the form read; reload after a concurrent edit. Repository YAML cannot change this list or borrow explicit-import authority.

The resolver owner must separately configure `automatic_inputs = []` (default deny) alongside `resolver = true` in the runner TOML. Configure exact URLs deliberately; no real-service entries ship in the example. The repository list and this ceiling are intersected for every acquisition. Job network profiles are unrelated. The UI shows each resolver's last reported ceiling and availability; a reported match is conditional on transport, address and redirect validation. Configuration changes take effect when the runner starts with that configuration; they do not cancel already-issued requests.

The supported automatic transport is **HTTPS downloads**, including the walker's recognized download/toolchain inputs, measured and uploaded to the controller's content-addressed store. URLs must use a lower-case DNS name and a simple ASCII path, at most 512 bytes; at most 16 entries. No query, percent escape, userinfo, explicit port, IP literal, fragment, wildcard, dot segment or prefix grant is accepted. Every redirect target needs an exact entry in both lists. Downloads behind signed query redirects are therefore unsupported. Every connection validates the entire DNS answer, rejects nonpublic/special-use addresses including mapped IPv6, then dials a validated literal with TLS verification of the original hostname. No inherited proxy, netrc, cookie jar, credential helper or default HTTP transport is used.

Automatic **Git/action origins and registry/image acquisition remain unsupported**. They refuse before subprocesses and cache reads even when the source appears in a policy. Existing explicit CI-policy imports retain their separate established authority and mappings. An approved exact-revision lock can still be reused without external acquisition; its original resolution provenance is shown instead of claiming a newly authorized fetch. Local actions and dependency-free workflows remain supported.

New automatic assignments bind the canonical policy text in signed `network-scope`, while `network` remains `locked`, mode remains `resolve-tag`, and authorization domain remains 6. `automatic-inputs: {version: 1, sources: [...]}` must match it exactly. Older runners reject the nonempty scope. Explicit imports and ordinary jobs remain domain 5. Supported pending state-6 automatic obligations retain their signed empty scope and zero-fetch authority; this cannot inherit a newly configured grant. The current runner accepts only that signed legacy zero-authority case without a new envelope.

The state holds maps for desired policies, captured policies, lock acquisition evidence and runner ceiling reports. A fresh ship starts with all four empty. Automatic locks bind policy/ceiling identities and exact download receipts into their digest. Policy edits retire open runs of the previous generation, obsolete completion is rejected, and shared work survives while another live approved owner needs it. Cancellation cannot recall external effects already started or undo completed downloads; already-issued store URLs retain their bounded expiry. Native upgrade, actual assignment capture and browser acceptance are separate parent checks.
