import { normalizeGroups } from './groupPolicy.js'

const BASE = '/apps/urgit/api'
const GROUPS_SCRY = '/~/scry/groups/groups/light.json'

const fileRoute = (name, path) => {
  const parts = path.split('/').filter(Boolean).map(encodeURIComponent)
  return `/repository/${encodeURIComponent(name)}/file/${parts.join('/')}`
}

const atRef = (path, ref) => ref ? `${path}?ref=${encodeURIComponent(ref)}` : path

async function request(path, options = {}) {
  const response = await fetch(`${BASE}${path}`, {
    credentials: 'same-origin',
    headers: options.body ? { 'content-type': 'application/json', ...options.headers } : options.headers,
    ...options,
  })
  const text = await response.text()
  let data = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    data = { error: text || `HTTP ${response.status}` }
  }
  if (!response.ok) throw new Error(data?.error || data?.message || `HTTP ${response.status}`)
  return data
}

const publicFileRoute = (name, path) => {
  const parts = path.split('/').filter(Boolean).map(encodeURIComponent)
  return `/public/repository/${encodeURIComponent(name)}/file/${parts.join('/')}`
}

export const publicApi = {
  profile: () => request('/public/profile'),
  repository: (name) => request(`/public/repository/${encodeURIComponent(name)}`),
  issue: (name, number) => request(`/public/repository/${encodeURIComponent(name)}/issues/${number}`),
  files: (name, ref) => request(atRef(`/public/repository/${encodeURIComponent(name)}/files`, ref)),
  file: (name, path, ref) => request(atRef(publicFileRoute(name, path), ref)),
  fileHistory: (name, path, ref) => request(atRef(publicFileRoute(name, path).replace('/file/', '/file-history/'), ref)),
  fileBlame: (name, path, ref) => request(atRef(publicFileRoute(name, path).replace('/file/', '/file-blame/'), ref)),
  commits: (name, ref, offset = 0, limit = 50) => request(`/public/repository/${encodeURIComponent(name)}/commits?ref=${encodeURIComponent(ref || '')}&offset=${offset}&limit=${limit}`),
  compare: (name, base, head) => request(`/public/repository/${encodeURIComponent(name)}/compare?base=${encodeURIComponent(base)}&head=${encodeURIComponent(head)}`),
  commit: (name, oid) => request(`/public/repository/${encodeURIComponent(name)}/commit/${encodeURIComponent(oid)}`),
  search: (name, query, ref) => request(`/public/repository/${encodeURIComponent(name)}/search?q=${encodeURIComponent(query)}${ref ? `&ref=${encodeURIComponent(ref)}` : ''}`),
  release: (name, tag) => request(`/public/repository/${encodeURIComponent(name)}/releases?tag=${encodeURIComponent(tag)}`),
  archiveUrl: (name, ref) => `${BASE}/public/repository/${encodeURIComponent(name)}/archive?ref=${encodeURIComponent(ref)}`,
}

export const api = {
  repositories: () => request('/repositories'),
  desks: () => request('/desks'),
  peerActivity: () => request('/peer/activity'),
  peers: () => request('/peer/peers'),
  addPeer: (ship) => request('/peer/peers', { method: 'POST', body: JSON.stringify({ ship }) }),
  removePeer: (ship) => request('/peer/peers', { method: 'DELETE', body: JSON.stringify({ ship }) }),
  peerBrowse: (ship, repository) => request(`/peer/browse/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}`, { method: 'POST', body: '{}' }),
  peerStamp: (ship, repository) => request(`/peer/stamp/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}`, { method: 'POST', body: '{}' }),
  peerDetail: (ship, repository, kind, number) => request('/peer/detail', {
    method: 'POST', body: JSON.stringify({ ship, repository, kind, number }),
  }),
  peerCommit: (ship, repository, oid) => request('/peer/commit', {
    method: 'POST', body: JSON.stringify({ ship, repository, oid }),
  }),
  peerFile: (ship, repository, path) => request(`/peer/file/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}/${path.split('/').filter(Boolean).map(encodeURIComponent).join('/')}`, { method: 'POST', body: '{}' }),
  peerBrowses: () => request('/peer/browses'),
  peerDeleteBrowse: (requestId) => request('/peer/browses', { method: 'DELETE', body: JSON.stringify({ request: requestId }) }),
  peerForgeRequests: () => request('/peer/forge'),
  peerForgeComment: (ship, repository, kind, number, body) => request('/peer/forge', {
    method: 'POST', body: JSON.stringify({ ship, repository, kind, number, body }),
  }),
  peerCreateIssue: (ship, repository, title, body) => request('/peer/issues', {
    method: 'POST', body: JSON.stringify({ ship, repository, title, body }),
  }),
  peerDeleteForgeRequest: (requestId) => request('/peer/forge', { method: 'DELETE', body: JSON.stringify({ request: requestId }) }),
  // a writer's approval of an untrusted CI candidate on another ship's
  // repository (P3 D9), tracked like a forge comment
  // a writer's labels for a pull request on another ship's repository: the
  // owner decides, and the answer is tracked like a forge comment (kind pull)
  peerPullLabels: (ship, repository, number, labels) => request('/peer/labels', {
    method: 'POST', body: JSON.stringify({ ship, repository, number, labels }),
  }),
  peerCiApprove: (ship, repository, candidate) => request('/peer/ci-approve', {
    method: 'POST', body: JSON.stringify({ ship, repository, candidate }),
  }),
  // a delegate's CI policy action on another ship's repository (P4,
  // rider 02): the same action body the owner would post, carried over
  // the peer protocol and judged by the owner's role bindings; tracked
  // like a forge comment (kind policy)
  peerCiAction: (ship, repository, action) => request('/peer/ci-action', {
    method: 'POST', body: JSON.stringify({ ship, repository, action }),
  }),
  clearPeerActivity: () => request('/peer/activity', { method: 'DELETE' }),
  peerDiscover: (ship) => request('/peer/discover', { method: 'POST', body: JSON.stringify({ ship }) }),
  // one catalog request to every seated member of a group this ship is in; `group` is a flag, ~host/name
  peerDiscoverGroup: (group) => request('/peer/discover-group', { method: 'POST', body: JSON.stringify({ group }) }),
  peerDiscoveries: () => request('/peer/discoveries'),
  peerDeleteDiscovery: (requestId) => request('/peer/discoveries', { method: 'DELETE', body: JSON.stringify({ request: requestId }) }),
  peerTransfers: () => request('/peer/transfers'),
  peerDeleteTransfer: (transfer) => request('/peer/transfers', { method: 'DELETE', body: JSON.stringify({ transfer }) }),
  peerFork: (ship, repository, name, publicRead) =>
    request('/peer/fork', { method: 'POST', body: JSON.stringify({ ship, repository, name, publicRead }) }),
  peerPush: (name) => request('/peer/push', { method: 'POST', body: JSON.stringify({ name }) }),
  peerPullRequest: (name, title, sourceBranch, targetBranch) => request('/peer/pull-request', {
    method: 'POST', body: JSON.stringify({ name, title, sourceBranch, targetBranch }),
  }),
  githubStatus: () => request('/github/status'),
  setGithubToken: (token) => request('/github/token', { method: 'POST', body: JSON.stringify({ token }) }),
  clearGithubToken: () => request('/github/token', { method: 'DELETE' }),
  githubImport: (owner, repository, name, publicRead) =>
    request('/github/import', { method: 'POST', body: JSON.stringify({ owner, repository, name, publicRead }) }),
  githubPush: (name, branch) => request(`/repository/${encodeURIComponent(name)}/github/push`, {
    method: 'POST', body: JSON.stringify({ branch }),
  }),
  githubMetadata: (name, kind, page = 1) => request(`/repository/${encodeURIComponent(name)}/github/metadata`, { method: 'POST', body: JSON.stringify({ kind, page }) }),
  githubIssue: (name, number) => request(`/repository/${encodeURIComponent(name)}/github/issues/${number}`),
  githubPullDetail: (name, number) => request(`/repository/${encodeURIComponent(name)}/github/pulls/${number}`),
  githubPullDiff: (name, number) => request(`/repository/${encodeURIComponent(name)}/github/pulls/${number}/diff`),
  githubFile: (name, path, ref) => request(atRef(fileRoute(name, path).replace('/file/', '/github/file/'), ref)),
  githubFork: (name) => request(`/repository/${encodeURIComponent(name)}/github/fork`, { method: 'POST', body: '{}' }),
  githubPull: (name, title, head, base, body) =>
    request(`/repository/${encodeURIComponent(name)}/github/pull`, {
      method: 'POST', body: JSON.stringify({ title, head, base, body }),
    }),
  repository: (name) => request(`/repository/${encodeURIComponent(name)}`),
  files: (name, ref) => request(atRef(`/repository/${encodeURIComponent(name)}/files`, ref)),
  file: (name, path, ref) => request(atRef(fileRoute(name, path), ref)),
  fileHistory: (name, path, ref) => request(atRef(fileRoute(name, path).replace('/file/', '/file-history/'), ref)),
  fileBlame: (name, path, ref) => request(atRef(fileRoute(name, path).replace('/file/', '/file-blame/'), ref)),
  saveFile: (name, path, content, message, ref = '') =>
    request(fileRoute(name, path), {
      method: 'POST',
      body: JSON.stringify({ content, message, ...(ref ? { ref } : {}) }),
    }),
  deleteFile: (name, path, message, ref = '') =>
    request(fileRoute(name, path), {
      method: 'DELETE',
      body: JSON.stringify({ message, ...(ref ? { ref } : {}) }),
    }),
  commits: (name, ref, offset = 0, limit = 50) => request(`/repository/${encodeURIComponent(name)}/commits?ref=${encodeURIComponent(ref || '')}&offset=${offset}&limit=${limit}`),
  compare: (name, base, head) => request(`/repository/${encodeURIComponent(name)}/compare?base=${encodeURIComponent(base)}&head=${encodeURIComponent(head)}`),
  commit: (name, oid) => request(`/repository/${encodeURIComponent(name)}/commit/${encodeURIComponent(oid)}`),
  search: (name, query, ref) => request(`/repository/${encodeURIComponent(name)}/search?q=${encodeURIComponent(query)}${ref ? `&ref=${encodeURIComponent(ref)}` : ''}`),
  create: (name, publicRead) =>
    request('/repositories', { method: 'POST', body: JSON.stringify({ name, publicRead }) }),
  remove: (name) => request(`/repository/${encodeURIComponent(name)}`, { method: 'DELETE' }),
  setPublic: (name, publicRead) =>
    request(`/repository/${encodeURIComponent(name)}/public`, {
      method: 'POST',
      body: JSON.stringify({ publicRead }),
    }),
  setDescription: (name, description) =>
    request(`/repository/${encodeURIComponent(name)}/description`, {
      method: 'POST',
      body: JSON.stringify({ description }),
    }),
  setNotifications: (name, events) =>
    request(`/repository/${encodeURIComponent(name)}/notifications`, {
      method: 'POST',
      body: JSON.stringify({ events }),
    }),
  createBranch: (name, branch, source) =>
    request(`/repository/${encodeURIComponent(name)}/branches`, {
      method: 'POST',
      body: JSON.stringify({ name: branch, source }),
    }),
  deleteBranch: (name, branch) =>
    request(`/repository/${encodeURIComponent(name)}/branches`, {
      method: 'DELETE',
      body: JSON.stringify({ name: branch }),
    }),
  setDefaultBranch: (name, branch) =>
    request(`/repository/${encodeURIComponent(name)}/branches/default`, {
      method: 'POST',
      body: JSON.stringify({ name: branch }),
    }),
  setWriter: (name, ship, allowed) =>
    request(`/repository/${encodeURIComponent(name)}/writers`, {
      method: 'POST',
      body: JSON.stringify({ ship, allowed }),
    }),
  setReader: (name, ship, allowed) =>
    request(`/repository/${encodeURIComponent(name)}/readers`, {
      method: 'POST',
      body: JSON.stringify({ ship, allowed }),
    }),
  setGroupPolicy: (name, policy) =>
    request(`/repository/${encodeURIComponent(name)}/group-policy`, {
      method: 'POST',
      body: JSON.stringify({ policy }),
    }),
  // every group this ship is in, hosted here or joined, read straight from the
  // Groups agent's light scry; `ourShip` only marks the ones hosted here
  listGroups: async (ourShip) => {
    let response
    try {
      response = await fetch(GROUPS_SCRY, { credentials: 'same-origin' })
    } catch (cause) {
      throw new Error(`Groups unavailable: ${cause.message}`)
    }
    if (!response.ok) throw new Error(`Groups unavailable: HTTP ${response.status}`)
    let data
    try {
      data = JSON.parse(await response.text())
    } catch {
      throw new Error('Groups unavailable: unreadable answer')
    }
    return normalizeGroups(data, ourShip)
  },
  setProtected: (name, ref, protectedBranch) =>
    request(`/repository/${encodeURIComponent(name)}/protected`, {
      method: 'POST',
      body: JSON.stringify({ ref, protected: protectedBranch }),
    }),
  createTag: (name, tag, target, message) =>
    request(`/repository/${encodeURIComponent(name)}/tags`, {
      method: 'POST',
      body: JSON.stringify({ name: tag, target, message }),
    }),
  deleteTag: (name, tag) =>
    request(`/repository/${encodeURIComponent(name)}/tags`, {
      method: 'DELETE',
      body: JSON.stringify({ name: tag }),
    }),
  createRelease: (name, tag, title, notes) =>
    request(`/repository/${encodeURIComponent(name)}/releases`, {
      method: 'POST', body: JSON.stringify({ tag, title, notes }),
    }),
  release: (name, tag) => request(`/repository/${encodeURIComponent(name)}/releases?tag=${encodeURIComponent(tag)}`),
  deleteRelease: (name, tag) =>
    request(`/repository/${encodeURIComponent(name)}/releases`, {
      method: 'DELETE', body: JSON.stringify({ tag }),
    }),
  archiveUrl: (name, ref) => `${BASE}/repository/${encodeURIComponent(name)}/archive?ref=${encodeURIComponent(ref)}`,
  createWebhook: (name, url, secret, events) =>
    request(`/repository/${encodeURIComponent(name)}/webhooks`, {
      method: 'POST', body: JSON.stringify({ url, secret, events }),
    }),
  deleteWebhook: (name, id) =>
    request(`/repository/${encodeURIComponent(name)}/webhooks`, {
      method: 'DELETE', body: JSON.stringify({ id }),
    }),
  testWebhook: (name, id) =>
    request(`/repository/${encodeURIComponent(name)}/webhooks/${id}/test`, { method: 'POST', body: '{}' }),
  setIncomingHook: (name, secret) =>
    request(`/repository/${encodeURIComponent(name)}/incoming-hook`, {
      method: 'POST', body: JSON.stringify({ secret }),
    }),
  clearIncomingHook: (name) =>
    request(`/repository/${encodeURIComponent(name)}/incoming-hook`, { method: 'DELETE', body: '{}' }),
  dismissUpstreamUpdate: (name, id) =>
    request(`/repository/${encodeURIComponent(name)}/upstream-updates`, {
      method: 'DELETE', body: JSON.stringify({ id }),
    }),
  createPull: (name, title, sourceBranch, targetBranch) =>
    request(`/repository/${encodeURIComponent(name)}/pulls`, {
      method: 'POST', body: JSON.stringify({ title, sourceBranch, targetBranch }),
    }),
  pull: (name, number) => request(`/repository/${encodeURIComponent(name)}/pulls/${number}`),
  addPullComment: (name, number, body, path = '', line = 0, side = '') =>
    request(`/repository/${encodeURIComponent(name)}/pulls/${number}/comments`, {
      method: 'POST', body: JSON.stringify({ body, path, line, side }),
    }),
  resolvePullComment: (name, number, comment, resolved) =>
    request(`/repository/${encodeURIComponent(name)}/pulls/${number}/comments/${comment}/resolve`, {
      method: 'POST', body: JSON.stringify({ resolved }),
    }),
  setPullState: (name, number, state) =>
    request(`/repository/${encodeURIComponent(name)}/pulls/${number}/state`, {
      method: 'POST', body: JSON.stringify({ state }),
    }),
  mergePull: (name, number) => request(`/repository/${encodeURIComponent(name)}/pulls/${number}/merge`, { method: 'POST', body: '{}' }),
  // a pull request's labels, replaced whole; the ship answers the labels it
  // holds, or refuses with its reason
  setPullLabels: (name, number, labels) =>
    request(`/repository/${encodeURIComponent(name)}/pulls/${number}/labels`, {
      method: 'POST', body: JSON.stringify({ labels }),
    }),
  createIssue: (name, title, body) =>
    request(`/repository/${encodeURIComponent(name)}/issues`, {
      method: 'POST', body: JSON.stringify({ title, body }),
    }),
  issue: (name, number) => request(`/repository/${encodeURIComponent(name)}/issues/${number}`),
  addIssueComment: (name, number, body) =>
    request(`/repository/${encodeURIComponent(name)}/issues/${number}/comments`, {
      method: 'POST', body: JSON.stringify({ body }),
    }),
  setIssueState: (name, number, state) =>
    request(`/repository/${encodeURIComponent(name)}/issues/${number}/state`, {
      method: 'POST', body: JSON.stringify({ state }),
    }),
  setIssueLabels: (name, number, labels) =>
    request(`/repository/${encodeURIComponent(name)}/issues/${number}/labels`, {
      method: 'POST', body: JSON.stringify({ labels }),
    }),
  setIssueAssignees: (name, number, assignees) =>
    request(`/repository/${encodeURIComponent(name)}/issues/${number}/assignees`, {
      method: 'POST', body: JSON.stringify({ assignees }),
    }),
  setToken: (name, token) =>
    request(`/repository/${encodeURIComponent(name)}/token`, {
      method: 'POST',
      body: JSON.stringify({ token }),
    }),
  clearToken: (name) =>
    request(`/repository/${encodeURIComponent(name)}/token`, { method: 'DELETE' }),
  bind: (name, desk, branch) =>
    request(`/repository/${encodeURIComponent(name)}/bind`, {
      method: 'POST',
      body: JSON.stringify({ desk, branch }),
    }),
  unbind: (name) =>
    request(`/repository/${encodeURIComponent(name)}/unbind`, { method: 'POST', body: '{}' }),
  publish: (name, message) =>
    request(`/repository/${encodeURIComponent(name)}/publish`, {
      method: 'POST',
      body: JSON.stringify({ message }),
    }),
  clayStatus: (name) =>
    request(`/repository/${encodeURIComponent(name)}/clay/status`),
  lfsGcPreview: (name) => request(`/repository/${encodeURIComponent(name)}/lfs/gc`),
  lfsGc: (name) => request(`/repository/${encodeURIComponent(name)}/lfs/gc`, {
    method: 'POST', body: '{}',
  }),
  applyToClay: (name) =>
    request(`/repository/${encodeURIComponent(name)}/clay/apply`, {
      method: 'POST',
      body: '{}',
  }),
}

export async function waitForPeerTransfer(transferId, { interval = 750, onProgress } = {}) {
  let missingPolls = 0
  while (true) {
    await new Promise((resolve) => setTimeout(resolve, interval))
    const status = await api.peerTransfers()
    const transfer = status.transfers?.find((item) => item.transfer === transferId)
    if (!transfer) {
      missingPolls += 1
      if (missingPolls >= 8) throw new Error('ship no longer tracks this peer transfer')
      continue
    }
    missingPolls = 0
    onProgress?.(transfer)
    if (!transfer.active) return transfer
  }
}

export async function waitForPeerBrowse(requestId, { interval = 500, onProgress } = {}) {
  let missingPolls = 0
  while (true) {
    await new Promise((resolve) => setTimeout(resolve, interval))
    const status = await api.peerBrowses()
    const browse = status.browses?.find((item) => item.request === requestId)
    if (!browse) {
      missingPolls += 1
      if (missingPolls >= 8) {
        const error = new Error('peer browse state was reset')
        error.code = 'PEER_BROWSE_MISSING'
        throw error
      }
      continue
    }
    missingPolls = 0
    onProgress?.(browse)
    if (!browse.active) return browse
  }
}

export async function waitForPeerForge(requestId, { interval = 500 } = {}) {
  let missingPolls = 0
  while (true) {
    await new Promise((resolve) => setTimeout(resolve, interval))
    const status = await api.peerForgeRequests()
    const request = status.requests?.find((item) => item.request === requestId)
    if (!request) {
      missingPolls += 1
      if (missingPolls >= 8) throw new Error('peer forge request state was reset')
      continue
    }
    missingPolls = 0
    if (!request.active) return request
  }
}

// the native CI surface (BRIEF-CI-P2 D6): the same origin, the second
// API base %urgit-ci binds under /apps/urgit/api/ci; every read and the
// action route are session-authorized like the rest of `api`
const CI = `${BASE}/ci`

async function ciRequest(path, options = {}) {
  const response = await fetch(`${CI}${path}`, {
    credentials: 'same-origin',
    headers: options.body ? { 'content-type': 'application/json', ...options.headers } : options.headers,
    ...options,
  })
  const text = await response.text()
  let data = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    data = { error: text || `HTTP ${response.status}` }
  }
  if (!response.ok) {
    // the ship's own answer, with its status: a refusal, never a request
    // whose answer was lost (which rejects without one)
    const error = new Error(data?.error || `HTTP ${response.status}`)
    error.status = response.status
    // a refusal of named fields (a manual run's inputs): each field's reason
    error.fields = data?.fields || null
    throw error
  }
  return data
}

export const ci = {
  candidates: (name, before) => ciRequest(`/repository/${encodeURIComponent(name)}/candidates${before ? `?before=${encodeURIComponent(before)}` : ''}`),
  candidate: (id) => ciRequest(`/candidate/${encodeURIComponent(id)}`),
  policy: (name) => ciRequest(`/repository/${encodeURIComponent(name)}/policy`),
  credentials: (name) => ciRequest(`/repository/${encodeURIComponent(name)}/credentials`),
  // P4: a lock by digest, the repository's audit trail, a shadow run
  lock: (name, digest) => ciRequest(`/repository/${encodeURIComponent(name)}/lock/${encodeURIComponent(digest)}`),
  resolve: (name, revision) => ciRequest(`/repository/${encodeURIComponent(name)}/resolve/${encodeURIComponent(revision)}`),
  audit: (name) => ciRequest(`/repository/${encodeURIComponent(name)}/audit`),
  shadow: (id) => ciRequest(`/shadow/${encodeURIComponent(id)}`),
  key: () => ciRequest('/key'),
  // the Runners panel (P3 D1/D3): every daemon record with the ship's
  // clock, and the mint that answers a fresh enrollment token exactly once
  runners: () => ciRequest('/runners'),
  mint: () => ciRequest('/runners/mint', { method: 'POST', body: '{}' }),
  // a runner's withheld slots (legacy-recovery UI ruling 01): its latest
  // retention report, its recovery commands and what the ship knows of each
  // retention's attempt; a release is POSTed through action
  recovery: (id) => ciRequest(`/runners/${encodeURIComponent(id)}/recovery`),
  // the storage reachability probe (P3 D5): the store's endpoint and one
  // unsigned URL under the CI prefix for THIS browser to fetch
  storageProbe: () => ciRequest('/storage/probe'),
  // CI recovery (CI-RECOVERY-1): the pause, the checkpoints with "written"
  // and "replica" apart, the checkpoint repository, the staged checkpoint
  // with its manifest and diff, and what restores brought back. The
  // recovery actions are POSTed through action
  recoveryState: () => ciRequest('/recovery'),
  // the poke as JSON; the ship answers 200 {ok} or the refusal
  action: (body) => ciRequest('/action', { method: 'POST', body: JSON.stringify(body) }),
  // manual runs (Delivery 1A): the workflows each branch's promoted
  // baseline declares for workflow_dispatch, with their inputs; and the
  // dispatch, answered with the run the ship recorded ({run, fresh}) or the
  // refusal (each refused input in `fields`)
  dispatchInventory: (name) => ciRequest(`/repository/${encodeURIComponent(name)}/dispatch`),
  dispatch: (name, body) => ciRequest(`/repository/${encodeURIComponent(name)}/dispatch`, { method: 'POST', body: JSON.stringify(body) }),
  // automatic events (Delivery 1C): the source events the ship recorded for
  // a repository, newest first, with what each selected; and the schedules
  // of its default branch with the ship's own next, last and missed times
  events: (name) => ciRequest(`/repository/${encodeURIComponent(name)}/events`),
  schedules: (name) => ciRequest(`/repository/${encodeURIComponent(name)}/schedules`),
  // the log route answers a 302 to a presigned store URL; the browser
  // follows it with no headers of its own and the text is act's jsonl
  logUrl: (attempt) => `${CI}/attempt/${encodeURIComponent(attempt)}/log`,
  log: async (attempt) => {
    const response = await fetch(`${CI}/attempt/${encodeURIComponent(attempt)}/log`, { credentials: 'same-origin', redirect: 'follow' })
    if (!response.ok) throw new Error(`log: HTTP ${response.status}`)
    return response.text()
  },
}
