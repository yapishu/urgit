// CI setup checklist and agent brief (hands-on review, 2026-10-19). The CI
// tab used to say nothing until a branch was CI-required with no runner.
// It now shows what this repository still needs, each step read from the
// ship's own state, and offers a Markdown brief an operator can hand to a
// coding agent. The brief never carries the enrollment token: the operator
// mints it and pastes it into the runner's config file themselves.

import { runnerState } from './runners.js'

const WORKFLOW_DIR = '.github/workflows/'

// the workflow files at the default branch's tip, from the file listing
export function workflowFiles(files = []) {
  return (files || [])
    .map((f) => String(f.path || f).replace(/^\//, ''))
    .filter((p) => p.startsWith(WORKFLOW_DIR) && /\.ya?ml$/.test(p) && !p.slice(WORKFLOW_DIR.length).includes('/'))
    .sort()
}

// runners able to take this repository's jobs now
export function runnersFor(repo, runners = [], nowSeconds = Date.now() / 1000) {
  return (runners || []).filter((r) => {
    const state = runnerState(r, nowSeconds)
    if (state !== 'healthy') return false
    return !Array.isArray(r.repos) || r.repos.includes(repo)
  })
}

// one step: done, todo, or info (cannot be decided from state)
const step = (id, title, status, detail, action = null) => ({ id, title, status, detail, action })

export function setupSteps({ repo, storage, runners, policy, workflows, nowSeconds = Date.now() / 1000 }) {
  const all = runners || []
  const enrolled = all.filter((r) => ['healthy', 'stale', 'refused'].includes(runnerState(r, nowSeconds)))
  const healthy = all.filter((r) => runnerState(r, nowSeconds) === 'healthy')
  const taking = runnersFor(repo, all, nowSeconds)
  const baselines = policy?.baselines || []
  const required = policy?.ciProtected || []
  const nets = policy?.networkPolicies || []
  const wf = workflows || []
  return [
    step('workflows', 'Repository has workflows',
      workflows === null ? 'unknown' : wf.length ? 'done' : 'todo',
      workflows === null ? 'The file list could not be read.'
        : wf.length ? `${wf.length} workflow file${wf.length === 1 ? '' : 's'} in ${WORKFLOW_DIR}: ${wf.join(', ')}.`
          : `No workflow files in ${WORKFLOW_DIR} on the default branch. Add GitHub Actions YAML there; see "Prepare your repository" in the setup guide for what is supported.`,
      { kind: 'guide', anchor: 'prepare-your-repository' }),
    step('storage', 'Object store configured',
      storage === 'unknown' ? 'unknown' : storage === 'unconfigured' ? 'todo' : 'done',
      storage === 'unconfigured' ? 'The ship has no S3-compatible store in %storage. CI keeps logs there and cannot be enabled without one.'
        : storage === 'unreachable' || storage === 'cors' ? 'Configured, but this browser cannot read from it: logs will not open here until it can (see the warning above).'
          : storage === 'unknown' ? 'The storage check could not run.' : 'Configured and reachable from this browser.',
      { kind: 'guide', anchor: '1-object-store' }),
    step('runner', 'A runner is installed',
      healthy.length ? 'done' : 'todo',
      healthy.length ? `${healthy.length} healthy runner${healthy.length === 1 ? '' : 's'}.`
        : enrolled.length ? 'A runner is enrolled but not healthy: it has not polled in five minutes. Check that its service is running.'
          : 'No runner is enrolled. Install the runner on a Linux host with KVM, then mint a token and paste it into its config.',
      { kind: 'settings' }),
    step('binding', 'A runner takes this repository',
      taking.length ? 'done' : 'todo',
      taking.length ? `${taking.length} healthy runner${taking.length === 1 ? '' : 's'} can take ${repo}'s jobs.`
        : healthy.length ? `No healthy runner takes ${repo}. Open Settings → Runners and choose Repositories… on a runner.`
          : 'Needs a healthy runner first.',
      { kind: 'settings' }),
    step('baseline', 'Workflows approved (baseline promoted)',
      baselines.length ? 'done' : 'todo',
      baselines.length ? `Promoted for ${baselines.map((b) => b.ref.replace('refs/heads/', '')).join(', ')}.`
        : 'Required checks run the workflow files of an approved revision. In Settings → CI policy, resolve dependencies for the branch tip, then promote it.',
      { kind: 'settings' }),
    step('required', 'A branch requires CI',
      required.length ? 'done' : 'todo',
      required.length ? `CI required on ${required.map((r) => r.replace('refs/heads/', '')).join(', ')}.`
        : 'Add a branch to Settings → CI-required branches. Until then pushes land without checks (manual runs and automatic events still work).',
      { kind: 'settings' }),
    step('network', 'Network access for jobs that need it', 'info',
      nets.length ? `${nets.length} job${nets.length === 1 ? ' has' : 's have'} a network rule. Every other job runs with no network.`
        : 'Every job runs with no network. A job that downloads (apt-get, curl, a pinned binary) needs a rule in Settings → CI policy → Network policies naming its destinations.',
      { kind: 'settings' }),
  ]
}

export const setupComplete = (steps) => steps.every((s) => s.status === 'done' || s.status === 'info')

const mark = { done: '[x]', todo: '[ ]', unknown: '[?]', info: '[i]' }

// the brief an operator hands to an agent. Public facts only: the ship's
// origin, the repository name and the checklist state. No token, no code,
// no credential.
export function agentBrief({ origin, ship, repo, steps, generated = new Date().toISOString() }) {
  const status = steps.map((s) => `- ${mark[s.status] || '[ ]'} **${s.title}**: ${s.detail}`).join('\n')
  return `# Set up urgit CI for \`${repo}\`

You are helping the owner of the Urbit ship \`${ship}\` set up native CI for
the repository \`${repo}\` in %urgit. Work on the runner host the owner
chooses. Generated ${generated} from the ship's state; re-check anything
you rely on.

Ship web address: ${origin}
Repository: ${repo}
Git remote: ${origin}/git/${repo}

## Current state

${status}

Legend: [x] done, [ ] to do, [?] could not be read, [i] owner's judgement.

## Rules for you, the agent

1. **Never run sudo or any command as root.** When a step needs root, write
   the exact commands in a fenced block, explain what each does, and wait
   until the owner says they ran them. Then check the result yourself.
2. **Never ask for, read, print or store a secret.** That includes the
   ship's login code (+code), the runner enrollment token, object-store
   keys and repository credentials. The owner pastes the enrollment token
   into \`/etc/urgit-runner.toml\` themselves. Do not open that file after
   they have; check enrollment from the runner's log and the ship instead.
3. **Download only from the sources named below**, and check every pinned
   SHA-256 before using a file. If a pin does not match, stop and report.
4. **Change no firewall, network, kernel or service setting** beyond what
   this document's install steps do.
5. **Stop and ask** when something does not match this document (a
   missing file, a different version, an unexpected error). Do not work
   around it, retry destructively, or delete state you did not create.
6. Report each step with the command you ran and the output that proves it.

## Step 1: check the runner host

The runner needs a Linux x86_64 host with:

- KVM: \`test -r /dev/kvm && test -w /dev/kvm\` as root, or check
  \`ls -l /dev/kvm\` and the group that owns it.
- cgroup v2: \`stat -fc %T /sys/fs/cgroup\` prints \`cgroup2fs\`.
- systemd, Git, and outbound HTTP(S) to the ship at ${origin}.
- Go 1.27 or later to build the runner and launcher from source (there is
  no prebuilt download in this release).
- Free disk: about 25 GiB per concurrent job plus the guest image.

Report what you found. Stop if KVM or cgroup v2 is missing.

## Step 2: get the source and build

The runner has its own repository. This release has no prebuilt runner
download. Clone it and check out the runner commit that matches the urgit
commit the ship runs. Its \`URGIT_COMMIT\` file names the urgit commit each
runner commit was tested against:

\`\`\`sh
git clone https://github.com/wundrellama/urgit-runner.git
\`\`\`

In that checkout:

\`\`\`sh
cd urgit-runner
CGO_ENABLED=0 go build -trimpath -o urgit-runner ./cmd/urgit-runner
CGO_ENABLED=0 go build -trimpath -o urgit-vm-launcher ./cmd/urgit-vm-launcher
\`\`\`

The guest image (kernel and root filesystem the job VMs boot) is built from
\`guest/\` with \`guest/build.sh\`. Read that script first and
tell the owner what it downloads and from where before running it.

Allowed downloads:

- The runner source, from its repository.
- Go modules for the build, from the module proxy Go is configured for.
- Firecracker v1.17.0 from
  \`https://github.com/firecracker-microvm/firecracker/releases\`. The
  extracted binaries must match these SHA-256 pins (also in
  \`launcher/urgit-vm-launcher.toml.example\`):
  firecracker \`99ad0f5cd0514a88aad0e9ae8cfdb3cc3b4ab9d190e1194602406c786b5de7a5\`,
  jailer \`65ef226e96f0ceda55ba643f445801ef2cc0ea667ef67cad8ac4f406c9c8434f\`.
- Whatever \`guest/build.sh\` fetches, after the owner has seen the
  list.

## Step 3: install the VM launcher (root: the owner runs this)

The launcher is the only root part. It starts one Firecracker microVM per
job under the jailer, as the unprivileged user \`urgit-vm\`. Prepare, for
the owner to run:

1. Create the system user \`urgit-vm\`.
2. Create the launcher's protected root (for example
   \`/var/lib/urgit-ci/{bin,images,jail,state}\`), owned by root.
3. Install \`urgit-vm-launcher\`, Firecracker and jailer v1.17.0 into
   \`bin/\`, and the built guest image into \`images/<manifest sha256>/\`.
4. Write \`/etc/urgit-vm-launcher.toml\` (mode 0600) from
   \`launcher/urgit-vm-launcher.toml.example\`: \`socket\`,
   \`socket_group\` and \`runner_uids\` must name the user the runner will
   run as; \`ceiling\` lists the network destinations any job may ever
   reach (empty means no job gets network).
5. Install \`launcher/urgit-vm-launcher.service\` with its paths
   adjusted, then \`systemctl daemon-reload\` and
   \`systemctl start urgit-vm-launcher\`.

Show the owner the complete file contents and commands before they run
them. Afterwards check: \`systemctl is-active urgit-vm-launcher\` prints
\`active\`, and the socket exists with the expected group.

## Step 4: configure the runner

Write \`urgit-runner.toml\` from \`urgit-runner.toml.example\` with:

\`\`\`toml
ship_url = "${origin}"
enroll_token = "PASTE-THE-TOKEN-HERE"
sandbox = "microvm"
launcher_socket = "<the launcher's socket>"
image_path = "<the guest image directory>"
resolver = true
capacity = 1
\`\`\`

Leave \`enroll_token\` as the placeholder. Then tell the owner:

> Open ${origin}/apps/urgit/, go to **${repo} → Settings → Runners**, click
> **Mint token**, and choose **Repositories…** to include \`${repo}\`. Copy
> the token and replace \`PASTE-THE-TOKEN-HERE\` in the config file yourself.
> Do not paste the token to me.

The owner installs the file as \`/etc/urgit-runner.toml\`, mode 0600.

## Step 5: start the runner

Install \`urgit-runner.service\` (it runs as an unprivileged user) and
start it; the owner runs any root part. Then check:

- \`journalctl -u urgit-runner\` shows a \`sandbox: microvm\` line and no
  error.
- The owner sees the runner as **healthy** in Settings → Runners.

The token is consumed on first start; the owner removes the
\`enroll_token\` line afterwards.

## Step 6: prepare the repository

These are the owner's decisions in the ship's web interface; explain them
and check each one is done:

1. **Workflows**: GitHub Actions YAML in \`.github/workflows/\`. What runs:
   \`runs-on\` of \`ubuntu-latest\`, \`self-hosted\`, \`linux\`, \`x64\`,
   \`ubuntu-22.04\`, \`ubuntu-24.04\` or a label the runner declares,
   \`needs\`, job and step \`if\`, and job outputs. So does workflow-level
   \`concurrency\` with \`cancel-in-progress\`, as on GitHub: a cancelled
   run's result is cancelled and it never lands. The events are \`push\`,
   \`pull_request\`, \`workflow_dispatch\` with inputs and \`schedule\`, with
   branch, tag and path filters. Pull request activities include
   \`labeled\` and \`unlabeled\`, and every pull request payload lists the
   labels. Refused with the reason: \`strategy.matrix\`, reusable workflows,
   job-level \`concurrency\` and \`pull_request_target\`. Read but ignored,
   so check them yourself: artifacts between jobs, \`GITHUB_TOKEN\` and the
   GitHub API, and Windows or macOS runners. Change such a workflow, or
   leave it out of the required set.
2. **Actions**: \`uses:\` actions are fetched once when the owner resolves
   dependencies, pinned in a lock, and served to jobs from the ship. Pin
   each action to a full commit SHA where you can.
3. **Approve the workflows**: Settings → CI policy → **Resolve
   dependencies** for the branch tip, then **Promote as baseline**.
4. **Network**: jobs run with no network by default. A job that downloads
   needs a rule in Settings → CI policy → **Network policies**: workflow
   file, job id, profile and \`proto:host:port\` destinations. Read the
   workflows and list, per job, every host it downloads from, for the owner
   to approve. The same destinations must be allowed by the runner and the
   launcher's \`ceiling\`.
5. **Secrets**: Settings → Credentials. The owner enters values; never you.
6. **Require CI**: Settings → **CI-required branches → Add branch**.
7. **Try it**: CI tab → **Run workflow** runs a workflow by hand without
   landing anything. Check every job passes before requiring CI.

## Done

CI is set up when every box in "Current state" above is ticked. Ask the
owner to download a fresh copy of this file from the CI tab to confirm.
`
}

export const briefFilename = (repo) => `urgit-ci-setup-${String(repo).replace(/[^a-zA-Z0-9._-]/g, '-')}.md`
