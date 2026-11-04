import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { arm, armsNamed, gaps } from './hoonSource.js'

const surface = readFileSync(
  new URL('../../desk/sur/git.hoon', import.meta.url),
  'utf8',
)
const agent = readFileSync(
  new URL('../../desk/app/urgit.hoon', import.meta.url),
  'utf8',
)
const migrationUrl = new URL('../../desk/lib/git-migrate.hoon', import.meta.url)
// the state migrations are lib/git-migrate's, which the agent imports whole;
// read in the tests that need it, so a missing library fails those alone
const migrations = () => readFileSync(migrationUrl, 'utf8')
const vectorUrl = new URL('../../desk/gen/git-migration-vector.hoon', import.meta.url)

function sourceBlock(source, start, end) {
  const startAt = source.indexOf(start)
  assert.notEqual(startAt, -1, `missing ${start}`)
  const endAt = source.indexOf(end, startAt + start.length)
  assert.notEqual(endAt, -1, `missing ${end} after ${start}`)
  return source.slice(startAt, endAt)
}

function moldFields(block) {
  return [...block.matchAll(/^\s+(?:\$:\s+)?([a-z][a-z0-9-]*)=/gm)].map(
    ([, field]) => field,
  )
}

test('published repository-1 remains reader-free and state-5 owns the current repository mold', () => {
  const repository1 = sourceBlock(surface, '+$  repository-1', '+$  state-1')
  assert.deepEqual(moldFields(repository1), [
    'owner',
    'public-read',
    'description',
    'head',
    'refs',
    'protected-refs',
    'objects',
    'writers',
    'write-token-hash',
    'lfs-objects',
    'lfs-uploads',
    'lfs-locks',
    'binding',
    'peer-origin',
    'github-origin',
    'github-issues',
    'github-pulls',
    'native-pulls',
    'native-issues',
    'releases',
    'webhooks',
    'incoming-hook',
    'webhook-deliveries',
    'upstream-updates',
    'notification-events',
  ])

  const state1 = sourceBlock(surface, '+$  state-1', '+$  state-2')
  assert.match(state1, /\$:\s+%1/)
  assert.match(state1, /repositories=\(map @t repository-1\)/)

  const state2 = sourceBlock(surface, '+$  state-2', '+$  state-3')
  assert.match(state2, /\$:\s+%2/)
  assert.match(state2, /repositories=\(map @t repository-3\)/)

  const state3 = sourceBlock(surface, '+$  state-3', '+$  state-4')
  assert.match(state3, /\$:\s+%3/)
  assert.match(state3, /repositories=\(map @t repository-3\)/)

  // state-4 is frozen on repository-4 (pull request labels came in state-5)
  const state4 = sourceBlock(surface, '+$  state-4', '+$  state-5')
  assert.match(state4, /\$:\s+%4/)
  assert.match(state4, /repositories=\(map @t repository-4\)/)

  const state5 = sourceBlock(surface, '+$  state-5', '+$  action')
  assert.match(state5, /\$:\s+%5/)
  assert.match(state5, /repositories=\(map @t repository\)/)
})

test('repository-3 freezes the pre-group shape and the current repository only appends the policy', () => {
  const repository3 = sourceBlock(surface, '+$  repository-3', '+$  state-2')
  const currentRepository = sourceBlock(surface, '+$  repository\n', '+$  state-0')
  assert.deepEqual(moldFields(currentRepository), [...moldFields(repository3), 'group-policy'])
  assert.match(currentRepository, /group-policy=\(unit group-policy\)/)
  assert.doesNotMatch(repository3, /group-policy/)
})

test('state-2 keeps the four fields installed ships stored, state-3 adds the queue, and state-4 and state-5 keep it', () => {
  // A stored %2 noun predates the fork queue. If state-2 grows a field, every
  // installed ship fails to load rather than migrating.
  const state2 = sourceBlock(surface, '+$  state-2', '+$  state-3')
  assert.deepEqual(moldFields(state2), [
    'repositories',
    'peers',
    'github-token',
  ])

  const state3 = sourceBlock(surface, '+$  state-3', '+$  state-4')
  assert.deepEqual(moldFields(state3), [
    'repositories',
    'peers',
    'github-token',
    'peer-prepare-queue',
  ])
  assert.match(state3, /peer-prepare-queue=\(map @uv peer-prepare-entry\)/)

  const state4 = sourceBlock(surface, '+$  state-4', '+$  state-5')
  assert.deepEqual(moldFields(state4), moldFields(state3))
  const state5 = sourceBlock(surface, '+$  state-5', '+$  action')
  assert.deepEqual(moldFields(state5), moldFields(state3))
})

test('migrate-state-2 carries the repositories forward and defaults the queue empty', () => {
  // the agent takes them from the library: imported whole, none of its own
  assert.ok(agent.split('\n').some((line) => line.startsWith('/+') && line.slice(2).split(',').map((entry) => entry.trim()).includes('*git-migrate')))
  for (const step of ['migrate-state-0', 'migrate-state-1', 'migrate-state-2', 'migrate-state-3', 'migrate-state-4']) {
    assert.equal(armsNamed(agent, step).length, 0, `the agent defines no ${step} of its own`)
  }
  const migrate = arm(migrations(), 'migrate-state-2')
  assert.match(migrate, /\|=  stored=state-2:git/)
  assert.match(migrate, /\^-  state-3:git/)
  // The repositories must come across; a migration that drops them is worse
  // than the crash it replaces.
  assert.match(
    migrate,
    /\[%3 repositories\.stored peers\.stored github-token\.stored ~\]/,
  )

  // migrate-state-1 must again produce a four-field %2, so the %0 and %1 paths
  // hand migrate-state-2 the same shape an installed ship stored.
  const migrateOne = arm(migrations(), 'migrate-state-1')
  assert.match(migrateOne, /\^-  state-2:git/)
  assert.match(migrateOne, /\[%2 migrated peers\.stored github-token\.stored\]/)
})

test('migrate-state-3 rewrites every stored repository without a group policy', () => {
  const migrate = arm(migrations(), 'migrate-state-3')
  assert.match(migrate, /\|=  stored=state-3:git/)
  assert.match(migrate, /\^-  state-4:git/)
  // inside lib/git-migrate the call is unqualified and names the library's own arm
  assert.match(migrate, /\(repository-3-to-4 \+\.i\.remaining\)/)
  assert.ok(arm(migrations(), 'repository-3-to-4'))
  assert.match(migrate, /\[%4 migrated peers\.stored github-token\.stored peer-prepare-queue\.stored\]/)
  assert.match(arm(migrations(), 'repository-3-to-4'), /\^-  repository-4:git/)
})

test('migrate-state-4 rewrites every stored repository with no label on any pull request', () => {
  const migrate = arm(migrations(), 'migrate-state-4')
  assert.match(migrate, /\|=  stored=state-4:git/)
  assert.match(migrate, /\^-  state-5:git/)
  assert.match(migrate, /\(repository-4-to-5 \+\.i\.remaining\)/)
  assert.match(migrate, /\[%5 migrated peers\.stored github-token\.stored peer-prepare-queue\.stored\]/)
  const repository = arm(migrations(), 'repository-4-to-5')
  assert.match(repository, /\|=  repo=repository-4:git/)
  assert.match(repository, /\(turn native-pulls\.repo pull-4-to-5\)/)
  // every field comes across in its place; only the pull requests change
  const currentRepository = sourceBlock(surface, '+$  repository\n', '+$  state-0')
  const copied = [...repository.matchAll(/^\s+(?::\*\s+)?([a-z][a-z0-9-]*)(?:\.repo)?$/gm)].map(([, field]) => field)
  assert.deepEqual(copied, moldFields(currentRepository))
  const pull = arm(migrations(), 'pull-4-to-5')
  assert.match(pull, /\|=  pull=native-pull-4:git/)
  assert.match(pull, /comments\.pull\n      ~\n  ==/)
  assert.match(arm(migrations(), 'settle-webhook-state'), /\|=  stored=state-5:git/)
})

test('published pull mold is preserved while current pulls pin source and target refs', () => {
  const publishedPull = sourceBlock(surface, '+$  native-pull-1\n', '+$  native-pull-4\n')
  assert.deepEqual(moldFields(publishedPull), [
    'number',
    'source-ship',
    'source-repository',
    'title',
    'state',
    'head',
    'base',
    'comments',
  ])

  const pullFields = [
    'number',
    'source-ship',
    'source-repository',
    'source-ref',
    'target-ref',
    'title',
    'state',
    'head',
    'base',
    'comments',
  ]
  // state-4's pull request, frozen; the current one appends its labels
  const statePull = sourceBlock(surface, '+$  native-pull-4\n', '+$  native-pull\n')
  assert.deepEqual(moldFields(statePull), pullFields)
  const currentPull = sourceBlock(surface, '+$  native-pull\n', '+$  issue-comment')
  assert.deepEqual(moldFields(currentPull), [...pullFields, 'labels'])
  assert.match(currentPull, /labels=\(set @t\)/)
  const repository3 = sourceBlock(surface, '+$  repository-3', '+$  state-2')
  const repository4 = sourceBlock(surface, '+$  repository-4', '+$  repository-3')
  assert.match(repository3, /native-pulls=\(list native-pull-4\)/)
  assert.match(repository4, /native-pulls=\(list native-pull-4\)/)

  const repository0 = sourceBlock(surface, '+$  repository-0', '+$  repository-1')
  const repository1 = sourceBlock(surface, '+$  repository-1', '+$  state-1')
  const currentRepository = sourceBlock(surface, '+$  repository', '+$  state-0')
  assert.match(repository0, /native-pulls=\(list native-pull-1\)/)
  assert.match(repository1, /native-pulls=\(list native-pull-1\)/)
  assert.match(currentRepository, /native-pulls=\(list native-pull\)/)
})

test('on-load migrates zero through four forward while accepting five', () => {
  assert.match(agent, /=\|  state-5:git/)
  const onLoad = sourceBlock(agent, '++  on-load', '++  on-poke')
  assert.match(onLoad, /\?\+\s+-\.q\.old\s+!!/)
  assert.match(onLoad, /=\/  loaded=state-5:git/)
  assert.ok(
    gaps(onLoad).includes(
      '%0  %-  migrate-state-4  %-  migrate-state-3  (migrate-state-2 (migrate-state-1 (migrate-state-0 !<(state-0:git old))))',
    ),
  )
  assert.ok(
    gaps(onLoad).includes('%1  %-  migrate-state-4  (migrate-state-3 (migrate-state-2 (migrate-state-1 !<(state-1:git old))))'),
  )
  assert.ok(onLoad.includes('%2  (migrate-state-4 (migrate-state-3 (migrate-state-2 !<(state-2:git old))))'))
  assert.ok(onLoad.includes('%3  (migrate-state-4 (migrate-state-3 !<(state-3:git old)))'))
  assert.ok(onLoad.includes('%4  (migrate-state-4 !<(state-4:git old))'))
  assert.ok(onLoad.includes('%5  !<(state-5:git old)'))
})

test('pure repository migration seam and non-empty Hoon vector are present', () => {
  assert.ok(existsSync(migrationUrl), 'missing desk/lib/git-migrate.hoon')
  assert.ok(existsSync(vectorUrl), 'missing desk/gen/git-migration-vector.hoon')
  if (!existsSync(migrationUrl) || !existsSync(vectorUrl)) return

  const migration = readFileSync(migrationUrl, 'utf8')
  const vector = readFileSync(vectorUrl, 'utf8')
  assert.match(migration, /\+\+  repository-1-to-2/)
  assert.match(migration, /repo=repository-1:git/)
  assert.match(migration, /\^-  repository-3:git/)
  assert.match(migration, /\+\+  repository-3-to-4/)
  assert.match(migration, /repo=repository-3:git/)
  assert.match(migration, /\^-  repository:git/)
  assert.match(vector, /repository-1-to-2:git-migrate/)
  assert.match(vector, /repository-3-to-4:git-migrate/)
  assert.match(vector, /\?>(?:\s+)?=\(~ group-policy\.current\)/)
  assert.match(vector, /old=repository-1:git/)
  assert.match(vector, /refs=\(map @t oid:git\)/)
  assert.match(vector, /objects=\(map oid:git object:git\)/)
  assert.match(vector, /notification-events=\(set notification-event:git\)/)
  assert.match(vector, /\?>(?:\s+)?=\(~ readers\.migrated\)/)
  assert.match(migration, /turn\s+native-pulls\.repo/)
  assert.match(migration, /source-ref=@t\s+''/)
  assert.match(migration, /target-ref=@t\s+head\.repo/)
  assert.match(vector, /native-pulls=\(list native-pull-1:git\)/)
  assert.match(vector, /=\('' source-ref\.migrated-pull\)/)
  assert.match(vector, /=\(head\.old target-ref\.migrated-pull\)/)
  assert.match(vector, /=\(comments\.old-pull comments\.migrated-pull\)/)
})
