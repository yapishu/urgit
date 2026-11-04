::  git-json: Repository browse, history, diff, and blame JSON
::
/-  git, git-peer
/+  git-blame, git-clay, git-codec, git-github, git-protocol, git-tree, *git-format, *git-repository
|%
+$  blame-table  [sources=(list json) remap=(map @ud @ud)]
++  repository-json-up-to
  |=  [name=@t repo=repository:git history-limit=@ud]
  ^-  json
  ::  refs/ci/* are %urgit-ci's scratch refs (a candidate's objects kept
  ::  reachable for the runner's clone); they are not part of the
  ::  repository's shape on either route: the authenticated
  ::  /apps/urgit/api/repository/<name> comes through here directly and
  ::  the public one through public-repository-json-up-to
  ::
  =.  refs.repo
    %-  malt
    %+  skip  ~(tap by refs.repo)
    |=  [ref=@t oid:git]
    =('refs/ci/' (end [3 8] ref))
  |^
    =/  writers-json=(list json)
      (turn ~(tap in writers.repo) |=(writer=@p s+(scot %p writer)))
    =/  readers-json=(list json)
      (turn ~(tap in readers.repo) |=(reader=@p s+(scot %p reader)))
    =/  protected-json=(list json)
      (turn ~(tap in protected-refs.repo) |=(ref=@t s+ref))
    =/  notification-events-json=(list json)
      (turn ~(tap in notification-events.repo) |=(event=notification-event:git s+event))
    =/  head-oid=(unit oid:git)  (~(get by refs.repo) head.repo)
    =/  head-files=(unit (map path flat-entry:git-tree))
      ?~  head-oid  ~
      (flatten-commit-index:git-tree objects.repo u.head-oid)
    =/  file-count=@ud  ?~(head-files 0 ~(wyt by u.head-files))
    =/  history=[count=@ud exact=?]
      (first-parent-count-up-to repo head.repo history-limit)
    =/  releases-json=(list json)
      %+  turn  ~(tap by releases.repo)
      |=  entry=[@t release:git]
      (release-json +.entry %.n)
    %-  pairs:enjs:format
    :~  ['name' s+name]
        ['owner' s+(scot %p owner.repo)]
        ['description' s+description.repo]
        ['publicRead' b+public-read.repo]
        ['head' s+head.repo]
        ['refs' [%a refs-json]]
        ['protectedRefs' [%a protected-json]]
        ['objectCount' n+(decimal ~(wyt by objects.repo))]
        ['fileCount' n+(decimal file-count)]
        ['commitCount' n+(decimal count.history)]
        ['commitCountExact' b+exact.history]
        ['branchCount' n+(decimal (ref-count-prefix refs.repo 'refs/heads/'))]
        ['tagCount' n+(decimal (ref-count-prefix refs.repo 'refs/tags/'))]
        ['lfsObjectCount' n+(decimal ~(wyt by lfs-objects.repo))]
        ['lfsLockCount' n+(decimal ~(wyt by lfs-locks.repo))]
        ['writeTokenSet' b+?=(^ write-token-hash.repo)]
        ['writers' [%a writers-json]]
        ['readers' [%a readers-json]]
        ['groupPolicy' (group-policy-json group-policy.repo)]
        ['pullRequests' [%a pulls-json]]
        :*  'nativeIssues'
            [%a (turn native-issues.repo |=(issue=native-issue:git (native-issue-json issue %.n)))]
        ==
        ['releases' [%a releases-json]]
        :*  'webhooks'
            [%a (turn ~(tap by webhooks.repo) |=(entry=[@ud webhook:git] (webhook-json +.entry)))]
        ==
        ['incomingHookConfigured' b+?=(^ incoming-hook.repo)]
        ['webhookDeliveries' [%a (turn (scag 100 webhook-deliveries.repo) webhook-delivery-json)]]
        :*  'upstreamUpdates'
            [%a (turn (dedupe-upstream-updates upstream-updates.repo) upstream-update-json)]
        ==
        ['notificationEvents' [%a notification-events-json]]
        ['githubIssues' [%a (turn github-issues.repo github-item-json)]]
        ['githubPulls' [%a (turn github-pulls.repo github-item-json)]]
        ['binding' (binding-json binding.repo)]
        ['peerOrigin' peer-origin-json]
        ['githubOrigin' github-origin-json]
    ==
  ++  peer-origin-json
    ^-  json
    ?~  peer-origin.repo  ~
    %-  pairs:enjs:format
    :~  ['ship' s+(scot %p ship.u.peer-origin.repo)]
        ['repository' s+repository.u.peer-origin.repo]
    ==
  ++  github-origin-json
    ^-  json
    ?~  github-origin.repo  ~
    %-  pairs:enjs:format
    :~  ['owner' s+owner.u.github-origin.repo]
        ['repository' s+repository.u.github-origin.repo]
    ==
  ++  refs-json
    %+  turn  ~(tap by refs.repo)
    |=  [ref=@t oid=oid:git]
    =/  peeled=(unit oid:git)  (peeled-tag:git-protocol objects.repo oid)
    =/  target=oid:git  ?~(peeled oid u.peeled)
    =/  mapped=(unit clay-link:git)
      ?~  binding.repo  ~
      (clay-link-for-commit target history.u.binding.repo)
    %-  pairs:enjs:format
    :~  ['name' s+ref]
        ['oid' s+(oid-text:git-codec oid)]
        ['targetOid' s+(oid-text:git-codec target)]
        ['clayRevision' n+(decimal ?~(mapped 0 clay-revision.u.mapped))]
    ==
  ++  pulls-json
    %+  turn  native-pulls.repo
    |=  pull=native-pull:git
    %-  pairs:enjs:format
    :~  ['number' n+(decimal number.pull)]
        ['sourceShip' s+(scot %p source-ship.pull)]
        ['sourceRepository' s+source-repository.pull]
        ['sourceRef' s+source-ref.pull]
        ['targetRef' s+target-ref.pull]
        ['title' s+title.pull]
        ['state' s+state.pull]
        ['head' s+(oid-text:git-codec head.pull)]
        ['base' s+(oid-text:git-codec base.pull)]
        ['commentCount' n+(decimal (lent comments.pull))]
        ['labels' (pull-labels-json labels.pull)]
    ==
  ++  github-item-json
    |=  item=forge-item:git
    ^-  json
    %-  pairs:enjs:format
    :~  ['number' n+(decimal number.item)]
        ['title' s+title.item]
        ['state' s+state.item]
        ['url' s+url.item]
        ['author' s+author.item]
        ['draft' b+draft.item]
    ==
  --
::
++  repository-json
  |=  [name=@t repo=repository:git]
  (repository-json-up-to name repo 10.000)
::
++  repositories-json
  |=  repos=(map @t repository:git)
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'repositories'
      :-  %a
      %+  turn  ~(tap by repos)
      |=  [name=@t repo=repository:git]
      (repository-json name repo)
  ==
::
++  public-repository-json-up-to
  |=  [name=@t repo=repository:git history-limit=@ud]
  ^-  json
  =/  full=json  (repository-json-up-to name repo history-limit)
  ?>  ?=([%o *] full)
  =/  fields=(map @t json)  p.full
  =.  fields  (~(del by fields) 'writeTokenSet')
  =.  fields  (~(del by fields) 'writers')
  =.  fields  (~(del by fields) 'readers')
  =.  fields  (~(del by fields) 'groupPolicy')
  =.  fields  (~(del by fields) 'binding')
  =.  fields  (~(del by fields) 'peerOrigin')
  =.  fields  (~(del by fields) 'webhooks')
  =.  fields  (~(del by fields) 'incomingHookConfigured')
  =.  fields  (~(del by fields) 'webhookDeliveries')
  =.  fields  (~(del by fields) 'notificationEvents')
  =.  fields  (~(del by fields) 'upstreamUpdates')
  [%o fields]
::
++  public-repository-json
  |=  [name=@t repo=repository:git]
  (public-repository-json-up-to name repo 10.000)
::
++  public-repositories-json
  |=  repos=(map @t repository:git)
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'repositories'
      :-  %a
      %+  turn  ~(tap by repos)
      |=  [name=@t repo=repository:git]
      (public-repository-json name repo)
  ==
::
++  repository-files-at-json-up-to
  |=  [name=@t repo=repository:git ref=@t history-limit=@ud]
  ^-  json
  =/  commit=(unit oid:git)  (revision-oid repo ref)
  =/  latest=(map path oid:git)
    (latest-file-commits-up-to repo ref history-limit)
  =/  summaries=(map oid:git json)
    %+  roll  ~(tap by latest)
    |=  [entry=[path oid:git] accumulator=(map oid:git json)]
    =/  commit-oid=oid:git  +.entry
    ?:  (~(has by accumulator) commit-oid)  accumulator
    =/  found=(unit object:git)  (~(get by objects.repo) commit-oid)
    ?.  &(?=(^ found) =(%commit kind.u.found))  accumulator
    (~(put by accumulator) commit-oid (commit-summary-json commit-oid data.u.found))
  =/  files=(unit (map path flat-entry:git-tree))
    ?~  commit  `*(map path flat-entry:git-tree)
    (flatten-commit-index:git-tree objects.repo u.commit)
  =/  file-json=(list json)
    ?~  files  ~
    %+  murn  ~(tap by u.files)
    |=  [file-path=path entry=flat-entry:git-tree]
    =/  blob=(unit object:git)  (~(get by objects.repo) oid.entry)
    ?.  &(?=(^ blob) =(%blob kind.u.blob))  ~
    =/  last-oid=(unit oid:git)  (~(get by latest) file-path)
    =/  last-summary=(unit json)
      ?~  last-oid  ~
      (~(get by summaries) u.last-oid)
    =/  last-commit=json
      ?~  last-summary  ~
      u.last-summary
    :-  ~
    %:  pairs:enjs:format
      ~[['path' s+(spat file-path)] ['size' n+(decimal p.data.u.blob)] ['lastCommit' last-commit]]
    ==
  %-  pairs:enjs:format
  :~  ['repository' s+name]
      ['head' s+ref]
      ['commit' s+?~(commit '' (oid-text:git-codec u.commit))]
      ['files' [%a file-json]]
  ==
::
++  repository-files-at-json
  |=  [name=@t repo=repository:git ref=@t]
  (repository-files-at-json-up-to name repo ref 10.000)
::
++  repository-files-json
  |=  [name=@t repo=repository:git]
  (repository-files-at-json name repo head.repo)
::
++  repository-search-json
  |=  [name=@t repo=repository:git ref=@t query=@t]
  ^-  json
  =/  commit=(unit oid:git)  (revision-oid repo ref)
  =/  files=(unit (map path octs))
    ?~  commit  ~
    (flatten-commit:git-tree objects.repo u.commit)
  =/  remaining=(list [path octs])  ?~(files ~ ~(tap by u.files))
  =/  results=(list json)  ~
  =/  count=@ud  0
  =/  scanned=@ud  0
  =/  finish
    |=  [entries=(list json) matches=@ud files-scanned=@ud truncated=?]
    ^-  json
    %-  pairs:enjs:format
    :~  ['repository' s+name]
        ['head' s+ref]
        ['commit' s+?~(commit '' (oid-text:git-codec u.commit))]
        ['query' s+query]
        ['matchCount' n+(decimal matches)]
        ['filesScanned' n+(decimal files-scanned)]
        ['truncated' b+truncated]
        ['results' [%a (flop entries)]]
    ==
  |-
  ?~  remaining  (finish results count scanned %.n)
  ?:  |((gte count 100) (gte scanned 2.000))
    (finish results count scanned %.y)
  =/  file=[file-path=path data=octs]  i.remaining
  =/  file-path=path  file-path.file
  =/  data=octs  data.file
  ?:  |(=(0 p.data) (gth p.data 2.097.152) ?=(^ (find-byte:git-clay data 0 0)))
    $(remaining t.remaining, scanned +(scanned))
  =/  scan-line
    |=  [offset=@ud line=@ud entries=(list json) matches=@ud]
    ^-  [(list json) @ud]
    ?:  |(=(offset p.data) (gte matches 100))  [entries matches]
    =/  newline=(unit @ud)  (find-byte:git-clay data offset 10)
    =/  end=@ud  ?~(newline p.data u.newline)
    =/  width=@ud  (sub end offset)
    =/  line-data=octs  (slice:git-codec data offset width)
    =/  hit=(unit @ud)  (find-sequence:git-github line-data query 0)
    =/  next-offset=@ud  ?~(newline p.data +(u.newline))
    ?~  hit
      $(offset next-offset, line +(line), entries entries, matches matches)
    =/  preview-start=@ud
      ?:  (gth u.hit 80)
        (sub u.hit 80)
      0
    =/  preview-width=@ud  (min 240 (sub width preview-start))
    =/  preview=octs  (slice:git-codec line-data preview-start preview-width)
    =/  entry=json
      %-  pairs:enjs:format
      :~  ['path' s+(spat file-path)]
          ['line' n+(decimal line)]
          ['column' n+(decimal +(u.hit))]
          ['preview' s+`@t`q.preview]
          ['previewOffset' n+(decimal preview-start)]
      ==
    $(offset next-offset, line +(line), entries [entry entries], matches +(matches))
  =/  searched=[(list json) @ud]  (scan-line 0 1 results count)
  $(remaining t.remaining, results -.searched, count +.searched, scanned +(scanned))
::
++  repository-file-json
  |=  [name=@t repo=repository:git ref=@t file-path=path data=octs]
  ^-  json
  %-  pairs:enjs:format
  :~  ['repository' s+name]
      ['head' s+ref]
      ['path' s+(spat file-path)]
      ['size' n+(decimal p.data)]
      ['encoding' s+'base64']
      ['content' s+(en:base64:mimes:html data)]
  ==
::
++  repository-file-history-json
  |=  [name=@t repo=repository:git ref=@t file-path=path]
  ^-  json
  =/  current=(unit oid:git)  (revision-oid repo ref)
  =/  entries=(list json)  ~
  =/  count=@ud  0
  |-
  ?:  |(?=(~ current) (gte count 100))
    %-  pairs:enjs:format
    :~  ['repository' s+name]
        ['head' s+ref]
        ['path' s+(spat file-path)]
        ['commits' [%a (flop entries)]]
    ==
  =/  found=(unit object:git)  (~(get by objects.repo) u.current)
  ?.  &(?=(^ found) =(%commit kind.u.found))
    %-  pairs:enjs:format
    :~  ['repository' s+name]
        ['head' s+ref]
        ['path' s+(spat file-path)]
        ['commits' [%a (flop entries)]]
    ==
  =/  parent=(unit oid:git)  (commit-parent data.u.found)
  =/  here=(unit octs)  (file-at-commit repo u.current file-path)
  =/  before=(unit octs)
    ?~  parent  ~
    (file-at-commit repo u.parent file-path)
  =/  next-entries=(list json)
    ?:  =(here before)  entries
    =/  entry=json
      %-  pairs:enjs:format
      :~  ['oid' s+(oid-text:git-codec u.current)]
          ['parent' s+?~(parent '' (oid-text:git-codec u.parent))]
          ['subject' s+(commit-subject data.u.found)]
          ['present' b+?=(^ here)]
          ['size' n+(decimal ?~(here 0 p.u.here))]
      ==
    [entry entries]
  $(current parent, entries next-entries, count +(count))
::
++  commit-identity-json
  |=  identity=(unit commit-identity)
  ^-  json
  ?~  identity  ~
  %-  pairs:enjs:format
  :~  ['name' s+name.u.identity]
      ['email' s+email.u.identity]
      ['timestamp' s+timestamp.u.identity]
      ['timezone' s+timezone.u.identity]
  ==
::
++  commit-summary-json
  |=  [oid=oid:git data=octs]
  ^-  json
  =/  parents=(list oid:git)  (commit-parents data)
  =/  parent=(unit oid:git)  ?~(parents ~ `i.parents)
  %-  pairs:enjs:format
  :~  ['oid' s+(oid-text:git-codec oid)]
      ['parent' s+?~(parent '' (oid-text:git-codec u.parent))]
      ['parents' [%a (turn parents |=(item=oid:git s+(oid-text:git-codec item)))]]
      ['subject' s+(commit-subject data)]
      ['author' (commit-identity-json (commit-identity-at data 'author '))]
      ['committer' (commit-identity-json (commit-identity-at data 'committer '))]
  ==
::
++  repository-commits-json-up-to
  |=  [name=@t repo=repository:git ref=@t offset=@ud limit=@ud count-limit=@ud]
  ^-  json
  =/  current=(unit oid:git)  (revision-oid repo ref)
  =/  entries=(list json)  ~
  =/  scanned=@ud  0
  =/  count=@ud  0
  =/  history=[count=@ud exact=?]
    (first-parent-count-up-to repo ref count-limit)
  =/  finish
    |=  [more=? page-count=@ud page-entries=(list json)]
    ^-  json
    %-  pairs:enjs:format
    :~  ['repository' s+name]
        ['head' s+ref]
        ['historyKind' s+'git']
        ['commitCount' n+(decimal count.history)]
        ['commitCountExact' b+exact.history]
        ['offset' n+(decimal offset)]
        ['nextOffset' n+(decimal (add offset page-count))]
        ['hasMore' b+more]
        ['commits' [%a (flop page-entries)]]
    ==
  |-
  ?~  current  (finish %.n count entries)
  ?:  (gte count limit)  (finish %.y count entries)
  =/  found=(unit object:git)  (~(get by objects.repo) u.current)
  ?~  found  (finish %.n count entries)
  ?.  =(%commit kind.u.found)  (finish %.n count entries)
  =/  parent=(unit oid:git)  (commit-parent data.u.found)
  ?:  (lth scanned offset)
    $(current parent, scanned +(scanned))
  =/  entry=json  (commit-summary-json u.current data.u.found)
  $(current parent, entries [entry entries], scanned +(scanned), count +(count))
::
++  repository-commits-json
  |=  [name=@t repo=repository:git ref=@t offset=@ud limit=@ud]
  (repository-commits-json-up-to name repo ref offset limit 10.000)
::
++  repository-browse-json
  |=  [name=@t repo=repository:git]
  ^-  json
  %-  pairs:enjs:format
  :~  ['revision' s+(repository-revision repo)]
      ['repository' (repository-json name repo)]
      ['files' (repository-files-json name repo)]
      ['commits' (repository-commits-json name repo head.repo 0 50)]
  ==
::
++  peer-repository-browse-json
  |=  [name=@t repo=repository:git]
  ^-  json
  %-  pairs:enjs:format
  :~  ['revision' s+(repository-revision repo)]
      ['repository' (public-repository-json-up-to name repo 50)]
      ::  Per-file history is supplemental browse metadata.  Keep this
      ::  bounded tightly: every revision requires a tree comparison, and
      ::  doing fifty of them can hold the source ship in %prepare for a
      ::  large repository before Fine or Mesa has even begun transferring.
      ['files' (repository-files-at-json-up-to name repo head.repo 10)]
      ['commits' (repository-commits-json-up-to name repo head.repo 0 50 50)]
  ==
::
++  repository-stamp-json
  |=  [name=@t repo=repository:git]
  ^-  json
  =/  identity=json
    (pairs:enjs:format ~[['name' s+name]])
  (pairs:enjs:format ~[['repository' identity] ['revision' s+(repository-revision repo)]])
::
++  repository-commit-json
  |=  [name=@t repo=repository:git oid=oid:git]
  ^-  (unit json)
  =/  found=(unit object:git)  (~(get by objects.repo) oid)
  ?.  &(?=(^ found) =(%commit kind.u.found))  ~
  =/  parent=(unit oid:git)  (commit-parent data.u.found)
  =/  current-files=(unit (map path octs))  (flatten-commit:git-tree objects.repo oid)
  ?~  current-files  ~
  =/  previous-files=(map path octs)
    ?~  parent  ~
    =/  flattened=(unit (map path octs))  (flatten-commit:git-tree objects.repo u.parent)
    ?~(flattened ~ u.flattened)
  =/  changed=(list json)
    %+  murn  ~(tap by u.current-files)
    |=  entry=[file-path=path data=octs]
    =/  previous=(unit octs)  (~(get by previous-files) file-path.entry)
    ?:  &(?=(^ previous) =(data.entry u.previous))  ~
    =/  status=@t  ?~(previous 'added' 'modified')
    =/  old-truncated=?  ?^(previous (gth p.u.previous 262.144) %.n)
    =/  new-truncated=?  (gth p.data.entry 262.144)
    =/  item=json
      %-  pairs:enjs:format
      :~  ['path' s+(spat file-path.entry)]
          ['status' s+status]
          ['oldSize' n+(decimal ?~(previous 0 p.u.previous))]
          ['newSize' n+(decimal p.data.entry)]
          ['oldContent' s+?~(previous '' ?:(old-truncated '' (en:base64:mimes:html u.previous)))]
          ['newContent' s+?:(new-truncated '' (en:base64:mimes:html data.entry))]
          ['truncated' b+|(old-truncated new-truncated)]
      ==
    `item
  =/  deleted=(list json)
    %+  murn  ~(tap by previous-files)
    |=  entry=[file-path=path data=octs]
    ?:  (~(has by u.current-files) file-path.entry)  ~
    =/  truncated=?  (gth p.data.entry 262.144)
    =/  item=json
      %-  pairs:enjs:format
      :~  ['path' s+(spat file-path.entry)]
          ['status' s+'deleted']
          ['oldSize' n+(decimal p.data.entry)]
          ['newSize' n+'0']
          ['oldContent' s+?:(truncated '' (en:base64:mimes:html data.entry))]
          ['newContent' s+'']
          ['truncated' b+truncated]
      ==
    `item
  =/  changes=(list json)  (weld changed deleted)
  =/  tree=(unit @t)  (commit-header data.u.found 'tree ')
  =/  result=json
    %-  pairs:enjs:format
    :~  ['repository' s+name]
        ['commit' (commit-summary-json oid data.u.found)]
        ['tree' s+?~(tree '' u.tree)]
        ['message' s+(commit-message data.u.found)]
        ['changedCount' n+(decimal (lent changes))]
        ['changes' [%a (scag 1.000 changes)]]
    ==
  `result
::
++  blame-safe
  |=  data=octs
  ^-  ?
  ?&  (lte p.data 262.144)
      ?=(~ (find-byte:git-clay data 0 0))
  ==
::
++  compact-blame-sources
  |=  [slots=(list slot:git-blame) sources=(list json)]
  ^-  blame-table
  =/  used=(set @ud)
    (silt (turn slots |=(item=slot:git-blame source.item)))
  =/  remaining=(list json)  sources
  =/  old-index=@ud  0
  =/  selected=(list json)  ~
  =/  remap=(map @ud @ud)  ~
  |-
  ?~  remaining  [selected remap]
  ?.  (~(has in used) old-index)
    $(remaining t.remaining, old-index +(old-index))
  =.  remap  (~(put by remap) old-index (lent selected))
  %=  $
    remaining  t.remaining
    old-index  +(old-index)
    selected  (weld selected ~[i.remaining])
    remap  remap
  ==
::
++  blame-lines-json
  |=  [slots=(list slot:git-blame) remap=(map @ud @ud)]
  ^-  (list json)
  =/  remaining=(list slot:git-blame)  slots
  =/  number=@ud  1
  =/  entries=(list json)  ~
  |-
  ?~  remaining  (flop entries)
  =/  mapped=(unit @ud)  (~(get by remap) source.i.remaining)
  ?>  ?=(^ mapped)
  =/  item=json
    %-  pairs:enjs:format
    ~[['line' n+(decimal number)] ['source' n+(decimal u.mapped)]]
  $(remaining t.remaining, number +(number), entries [item entries])
::
++  file-blame-result-json
  |=  $:  name=@t
          ref=@t
          file-path=path
          kind=@t
          slots=(list slot:git-blame)
          sources=(list json)
          truncated=?
      ==
  ^-  json
  =/  table=blame-table  (compact-blame-sources slots sources)
  %-  pairs:enjs:format
  :~  ['repository' s+name]
      ['head' s+ref]
      ['path' s+(spat file-path)]
      ['historyKind' s+kind]
      ['lineCount' n+(decimal (lent slots))]
      ['sourceCount' n+(decimal (lent sources.table))]
      ['truncated' b+truncated]
      ['sources' [%a sources.table]]
      ['lines' [%a (blame-lines-json slots remap.table)]]
  ==
::
++  git-file-blame-json
  |=  [name=@t repo=repository:git ref=@t file-path=path]
  ^-  (unit json)
  =/  current=(unit oid:git)  (revision-oid repo ref)
  ?~  current  ~
  =/  found=(unit object:git)  (~(get by objects.repo) u.current)
  ?.  &(?=(^ found) =(%commit kind.u.found))  ~
  =/  current-data=(unit octs)  (file-at-commit repo u.current file-path)
  ?.  &(?=(^ current-data) (blame-safe u.current-data))  ~
  =/  slots=(list slot:git-blame)  (seed:git-blame u.current-data)
  ?:  (gth (lent slots) 10.000)  ~
  =/  sources=(list json)  ~[(commit-summary-json u.current data.u.found)]
  =/  cursor=oid:git  u.current
  =/  cursor-data=octs  data.u.found
  =/  scanned=@ud  1
  |-
  ?:  !(any-active:git-blame slots)
    `(file-blame-result-json name ref file-path 'git' slots sources %.n)
  ?:  (gte scanned 200)
    `(file-blame-result-json name ref file-path 'git' slots sources %.y)
  =/  parent=(unit oid:git)  (commit-parent cursor-data)
  ?~  parent
    `(file-blame-result-json name ref file-path 'git' slots sources %.n)
  =/  parent-object=(unit object:git)  (~(get by objects.repo) u.parent)
  ?.  &(?=(^ parent-object) =(%commit kind.u.parent-object))
    `(file-blame-result-json name ref file-path 'git' slots sources %.y)
  =/  parent-data=(unit octs)  (file-at-commit repo u.parent file-path)
  ?~  parent-data
    `(file-blame-result-json name ref file-path 'git' (deactivate:git-blame slots) sources %.n)
  ?.  (blame-safe u.parent-data)
    `(file-blame-result-json name ref file-path 'git' slots sources %.y)
  =/  next-slots=(list slot:git-blame)
    (step:git-blame slots u.parent-data scanned)
  =/  next-sources=(list json)
    (weld sources ~[(commit-summary-json u.parent data.u.parent-object)])
  %=  $
    slots  next-slots
    sources  next-sources
    cursor  u.parent
    cursor-data  data.u.parent-object
    scanned  +(scanned)
  ==
::
++  repository-diff-json
  |=  [name=@t repo=repository:git base=oid:git head=oid:git]
  ^-  (unit json)
  =/  base-files=(unit (map path octs))  (flatten-commit:git-tree objects.repo base)
  =/  head-files=(unit (map path octs))  (flatten-commit:git-tree objects.repo head)
  ?.  &(?=(^ base-files) ?=(^ head-files))  ~
  =/  changed=(list json)
    %+  murn  ~(tap by u.head-files)
    |=  entry=[file-path=path data=octs]
    =/  previous=(unit octs)  (~(get by u.base-files) file-path.entry)
    ?:  &(?=(^ previous) =(data.entry u.previous))  ~
    =/  status=@t  ?~(previous 'added' 'modified')
    =/  old-truncated=?  ?^(previous (gth p.u.previous 262.144) %.n)
    =/  new-truncated=?  (gth p.data.entry 262.144)
    =/  item=json
      %-  pairs:enjs:format
      :~  ['path' s+(spat file-path.entry)]
          ['status' s+status]
          ['oldSize' n+(decimal ?~(previous 0 p.u.previous))]
          ['newSize' n+(decimal p.data.entry)]
          ['oldContent' s+?~(previous '' ?:(old-truncated '' (en:base64:mimes:html u.previous)))]
          ['newContent' s+?:(new-truncated '' (en:base64:mimes:html data.entry))]
          ['truncated' b+|(old-truncated new-truncated)]
      ==
    `item
  =/  deleted=(list json)
    %+  murn  ~(tap by u.base-files)
    |=  entry=[file-path=path data=octs]
    ?:  (~(has by u.head-files) file-path.entry)  ~
    =/  truncated=?  (gth p.data.entry 262.144)
    =/  item=json
      %-  pairs:enjs:format
      :~  ['path' s+(spat file-path.entry)]
          ['status' s+'deleted']
          ['oldSize' n+(decimal p.data.entry)]
          ['newSize' n+'0']
          ['oldContent' s+?:(truncated '' (en:base64:mimes:html data.entry))]
          ['newContent' s+'']
          ['truncated' b+truncated]
      ==
    `item
  =/  changes=(list json)  (weld changed deleted)
  =/  result=json
    %-  pairs:enjs:format
    :~  ['repository' s+name]
        ['base' s+(oid-text:git-codec base)]
        ['head' s+(oid-text:git-codec head)]
        ['changedCount' n+(decimal (lent changes))]
        ['changesTruncated' b+(gth (lent changes) 1.000)]
        ['changes' [%a (scag 1.000 changes)]]
    ==
  `result
::
::
++  native-pull-detail-json
  |=  [name=@t repo=repository:git pull=native-pull:git]
  ^-  (unit json)
  =/  diff=(unit json)  (repository-diff-json name repo base.pull head.pull)
  ?~  diff  ~
  ?.  ?=([%o *] u.diff)  ~
  =/  fields=(map @t json)  p.u.diff
  =.  fields  (~(put by fields) 'number' n+(decimal number.pull))
  =.  fields  (~(put by fields) 'title' s+title.pull)
  =.  fields  (~(put by fields) 'state' s+state.pull)
  =.  fields  (~(put by fields) 'sourceShip' s+(scot %p source-ship.pull))
  =.  fields  (~(put by fields) 'sourceRepository' s+source-repository.pull)
  =.  fields  (~(put by fields) 'sourceRef' s+source-ref.pull)
  =.  fields  (~(put by fields) 'targetRef' s+target-ref.pull)
  =.  fields  (~(put by fields) 'comments' [%a (turn comments.pull review-comment-json)])
  =.  fields  (~(put by fields) 'labels' (pull-labels-json labels.pull))
  `[%o fields]
::
::  a pull request's labels in name order (aor), as the CI payload lists
::  them
::
++  pull-labels-json
  |=  labels=(set @t)
  ^-  json
  =/  names=(list @t)  (sort ~(tap in labels) aor)
  [%a (turn names |=(label=@t s+label))]
::
--
