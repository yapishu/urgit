// The JSON %urgit-ci serves for Delivery 1C, as desk/app/urgit-ci.hoon
// builds it (candidate-json's event, selection and requiredEvidence;
// events-json; schedules-json). A MODEL of the wire read from the agent's
// source, labelled as such: not a captured response. The parent's live
// recipe (PARENT-ACCEPTANCE.md) reads the real one.

export const oid = (c) => c.repeat(40)

const outcome = (workflow, name, verdict, reason) => ({ workflow, name, verdict, reason })

const base = {
  repo: 'demo',
  ref: 'refs/heads/main',
  head: oid('c'),
  base: oid('b'),
  candidate: oid('c'),
  conflict: false,
  status: 'pending',
  trust: 'trusted',
  actor: '~zod',
  via: 'token',
  pull: null,
  verdictReason: null,
  waits: [],
  planned: false,
  plan: null,
  created: 1792152000,
  updated: 1792152000,
  generation: 4,
  currentGeneration: 4,
  baseline: oid('a'),
  lock: '1'.repeat(64),
  incarnation: '0v9.eeeee',
  sandbox: 'vm',
  trialOf: null,
  harnessDiffers: false,
  bindingsCurrent: true,
  landable: false,
  approvals: [],
  overrides: [],
  attempts: [],
}

const eventCommon = (extra) => ({
  workflow: null,
  inputs: [],
  actor: '~zod',
  ref: 'refs/heads/main',
  source: oid('c'),
  revision: oid('a'),
  payload: '{"ref":"refs/heads/main"}',
  payloadSha256: 'f'.repeat(64),
  ...extra,
})

export const pushSelection = {
  basis: `push to refs/heads/main: ${oid('b')}..${oid('c')} (two-dot); 1 changed path(s)`,
  note: null,
  outcomes: [
    outcome('a-branches.yml', 'Branches and paths', 'selected', 'branch main passes branches [main]; src/app.js passes paths [src/**]'),
    outcome('docs.yml', 'Docs', 'excluded', 'branch main passes branches [main]; but no changed path passes paths [docs/**] (1 changed)'),
    outcome('broken.yml', 'Broken on', 'error', "the workflow's on: is refused: on: lists push twice"),
  ],
}

export const pushRun = {
  ...base,
  id: '0v1.push',
  mode: 'event',
  event: eventCommon({
    name: 'push',
    kind: 'push',
    eventId: '0v5.eeeee',
    route: 'smart-http push (write token)',
    at: 1792152000,
    before: oid('b'),
    after: oid('c'),
    pull: null,
    occurrence: null,
    trigger: `push refs/heads/main ${oid('b')}..${oid('c')} event 0v5.eeeee`,
  }),
  selection: pushSelection,
  requiredEvidence: null,
}

export const newBranchRun = {
  ...pushRun,
  id: '0v1.newbranch',
  ref: 'refs/heads/feature',
  event: { ...pushRun.event, ref: 'refs/heads/feature', before: null, trigger: `push refs/heads/feature ${'0'.repeat(40)}..${oid('c')} event 0v5.fffff` },
}

export const pullFacts = {
  number: 7,
  title: 'Add <b>x</b>',
  action: 'opened',
  head: oid('d'),
  headRef: 'refs/heads/feature',
  baseRef: 'refs/heads/main',
  base: oid('b'),
  merged: false,
  sourceShip: '~nec',
  sourceRepository: 'demo',
}

export const pullRun = {
  ...base,
  id: '0v1.pull',
  mode: 'event',
  trust: 'untrusted',
  pull: 7,
  head: oid('d'),
  candidate: null,
  event: eventCommon({
    name: 'pull_request',
    kind: 'pull-request',
    eventId: '0v6.fffff',
    route: 'pull request API',
    at: 1792152060,
    before: null,
    after: oid('d'),
    pull: pullFacts,
    occurrence: null,
    source: oid('d'),
    trigger: `pull_request #7 opened head ${oid('d')} base ${oid('b')} event 0v6.fffff`,
  }),
  selection: { basis: `pull request #7 opened: head ${oid('d')} into refs/heads/main at ${oid('b')} (three-dot, from the merge base)`, note: null, outcomes: [outcome('a-branches.yml', 'Branches and paths', 'selected', 'activity opened is in types [opened, synchronize, reopened]; target main passes branches [main]')] },
  requiredEvidence: null,
}

export const mergedPull = { ...pullFacts, action: 'closed', merged: true }

export const scheduleRun = {
  ...base,
  id: '0v1.sched',
  mode: 'event',
  actor: '~zod',
  event: eventCommon({
    name: 'schedule',
    kind: 'schedule',
    eventId: '0v8.hhhhh',
    route: 'schedule (system timer)',
    at: 1792157400,
    before: null,
    after: oid('c'),
    pull: null,
    occurrence: {
      workflow: 'nightly.yml',
      index: 0,
      cron: '30 5 * * 1-5',
      timezone: 'America/New_York',
      due: { at: 1792157400, utc: '2026-10-16T09:30:00Z', local: '2026-10-16 05:30 UTC-04:00' },
      admitted: { at: 1792157525, utc: '2026-10-16T09:32:05Z', local: '2026-10-16 05:32 UTC-04:00' },
      lateSeconds: 125,
      late: true,
      definition: '0v7.ggggg',
      promoter: '~zod',
      promoted: 1791000000,
    },
    trigger: 'schedule nightly.yml#0 due 2026-10-16T09:30:00Z occurrence 0v8.hhhhh',
  }),
  selection: { basis: 'schedule 30 5 * * 1-5 (America/New_York) due 2026-10-16T09:30:00Z', note: null, outcomes: [outcome('nightly.yml', 'Nightly', 'selected', 'due 2026-10-16T09:30:00Z (2026-10-16 05:30 UTC-04:00); admitted late at 2026-10-16T09:32:05Z')] },
  requiredEvidence: null,
}

export const blockedRequired = {
  ...base,
  id: '0v1.required',
  mode: 'required',
  status: 'pending',
  via: 'session',
  event: eventCommon({ name: 'push', payload: null, payloadSha256: null, trigger: `push refs/heads/main ${oid('b')}..${oid('c')}` }),
  verdictReason: 'required evidence absent: docs.yml was not selected (branch main passes branches [main]; but no changed path passes paths [docs/**] (1 changed)); no attempt stands for it, the ref stays blocked, and only a recorded override lands it',
  selection: { ...pushSelection, outcomes: [pushSelection.outcomes[0], pushSelection.outcomes[1]] },
  requiredEvidence: { complete: false, evaluated: true, missing: [pushSelection.outcomes[1]] },
}

export const unevaluatedRequired = {
  ...blockedRequired,
  id: '0v1.unknown',
  verdictReason: null,
  selection: { basis: `push to refs/heads/main: ${oid('b')}..${oid('c')} (two-dot)`, note: 'filters not evaluated, every push workflow runs as before: the baseline of refs/heads/main was resolved before trigger definitions were read', outcomes: [] },
  requiredEvidence: { complete: true, evaluated: false, missing: [] },
}

export const eventsAnswer = {
  repo: 'demo',
  now: 1792160000,
  events: [
    { id: '0v5.eeeee', kind: 'push', ref: 'refs/heads/main', before: oid('b'), after: oid('c'), pull: null, actor: '~zod', route: 'smart-http push (write token)', at: 1792152000, received: 1792152001, outcome: '1 workflow(s) selected: run 0v1.push', selection: pushSelection, runs: ['0v1.push'] },
    { id: '0v5.ggggg', kind: 'push', ref: 'refs/heads/feature', before: null, after: oid('c'), pull: null, actor: '~nec', route: 'branch API', at: 1792151000, received: 1792151000, outcome: 'no workflow selected (2 declare push; see each reason)', selection: { basis: 'push to refs/heads/feature: a new ref', note: null, outcomes: [outcome('a-branches.yml', 'Branches and paths', 'excluded', 'branch feature does not pass branches [main]')] }, runs: [] },
    { id: '0v5.hhhhh', kind: 'push', ref: 'refs/tags/old', before: oid('b'), after: null, pull: null, actor: '~zod', route: 'tag API', at: 1792150000, received: 1792150000, outcome: 'recorded: a deletion runs no workflow (the delete event is not implemented)', selection: null, runs: [] },
    { id: '0v6.fffff', kind: 'pull-request', ref: 'refs/heads/main', before: null, after: oid('d'), pull: pullFacts, actor: '~nec', route: 'pull request API', at: 1792149000, received: 1792149000, outcome: '1 workflow(s) selected: run 0v1.pull', selection: pullRun.selection, runs: ['0v1.pull'] },
    { id: '0v6.iiiii', kind: 'pull-request', ref: 'refs/heads/main', before: null, after: oid('d'), pull: mergedPull, actor: '~zod', route: 'pull request merge', at: 1792148000, received: 1792148000, outcome: 'refused: pull request #7 is open now, not what closed leaves: stale', selection: null, runs: [] },
    { id: '0v9.jjjjj', kind: 'default-branch', ref: 'refs/heads/trunk', before: null, after: null, pull: null, actor: '~zod', route: 'default branch API', at: 1792147000, received: 1792147000, outcome: 'recorded: the default branch moved from refs/heads/main to refs/heads/trunk; its schedules were registered again', selection: null, runs: [] },
  ],
}

const instant = (at, utc, local) => ({ at, utc, local })

export const schedulesAnswer = {
  repo: 'demo',
  now: 1792160000,
  nowUtc: '2026-10-16T10:13:20Z',
  defaultBranch: 'refs/heads/main',
  refresh: null,
  schedules: [
    {
      workflow: 'nightly.yml', index: 0, name: 'Nightly', cron: '30 5 * * 1-5', timezone: 'America/New_York', timezoneLabel: 'America/New_York',
      state: 'active', reason: null, refusal: null, ref: 'refs/heads/main', baseline: oid('a'), lock: '1'.repeat(64),
      promoter: '~zod', promoted: 1791000000, registered: 1791000100, definition: '0v7.ggggg',
      next: instant(1792416600, '2026-10-19T09:30:00Z', '2026-10-19 05:30 UTC-04:00'),
      lastDue: instant(1792157400, '2026-10-16T09:30:00Z', '2026-10-16 05:30 UTC-04:00'),
      lastAdmitted: { due: instant(1792157400, '2026-10-16T09:30:00Z', '2026-10-16 05:30 UTC-04:00'), at: instant(1792157525, '2026-10-16T09:32:05Z', '2026-10-16 05:32 UTC-04:00'), run: '0v1.sched', late: true, lateSeconds: 125 },
      missed: [{ first: instant(1791984600, '2026-10-14T09:30:00Z', '2026-10-14 05:30 UTC-04:00'), last: instant(1792071000, '2026-10-15T09:30:00Z', '2026-10-15 05:30 UTC-04:00'), count: 2 }],
      staleWakes: 1,
    },
    {
      workflow: 'nightly.yml', index: 1, name: 'Nightly', cron: '*/4 * * * *', timezone: null, timezoneLabel: 'UTC (default)',
      state: 'refused', reason: 'the schedule runs 4 minute(s) apart; GitHub Actions runs scheduled workflows at most once every five minutes, and this one is refused rather than clamped', refusal: 'the schedule runs 4 minute(s) apart; GitHub Actions runs scheduled workflows at most once every five minutes, and this one is refused rather than clamped',
      ref: 'refs/heads/main', baseline: oid('a'), lock: '1'.repeat(64), promoter: '~zod', promoted: 1791000000, registered: 1791000100, definition: '0v7.kkkkk',
      next: null, lastDue: null, lastAdmitted: null, missed: [], staleWakes: 0,
    },
    {
      workflow: 'weekly.yml', index: 0, name: 'Weekly', cron: '0 6 * * 1', timezone: null, timezoneLabel: 'UTC (default)',
      state: 'retired', reason: 'the default branch moved from refs/heads/old to refs/heads/main: no longer defined', refusal: null,
      ref: 'refs/heads/old', baseline: oid('e'), lock: '2'.repeat(64), promoter: '~nec', promoted: 1790000000, registered: 1790000100, definition: '0v7.lllll',
      next: null, lastDue: null, lastAdmitted: null, missed: [], staleWakes: 0,
    },
  ],
}

export const schedulesNeedRefresh = {
  ...schedulesAnswer,
  refresh: 'the baseline of refs/heads/main was resolved before trigger definitions were read: its events are unknown, and nothing runs automatically until its revision is resolved and promoted again',
  schedules: [],
}

// a ci API over these answers, counting its reads; failRead makes the next
// read reject as a dropped connection would
export function modelCi({ events = eventsAnswer, schedules = schedulesAnswer } = {}) {
  const ship = {
    reads: { events: 0, schedules: 0 },
    failRead: false,
    events: async (name) => {
      ship.reads.events++
      if (ship.failRead) throw new TypeError('Failed to fetch')
      return { ...events, repo: name }
    },
    schedules: async (name) => {
      ship.reads.schedules++
      if (ship.failRead) throw new TypeError('Failed to fetch')
      return { ...schedules, repo: name }
    },
  }
  return ship
}
