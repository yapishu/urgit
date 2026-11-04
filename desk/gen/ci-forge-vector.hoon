::  ci-forge-vector: what %urgit reports of one persisted write (Delivery
::  1C), from its repositories before and after the event.  Checked here:
::    - nothing for an event that changed nothing a run could be for: no
::      write at all, a description, a review comment, refs/ci/ scratch;
::    - ref moves, creations and deletions, in name order, each with the
::      identity of its facts and instant: a redelivery is the same id, the
::      same move at another instant a new one;
::    - pull request transitions: opened, closed, merged (closed and
::      merged, with the target's tip before the merge from the same
::      event), reopened, synchronize; none for a request created closed or
::      a merged one closed again;
::    - a default-branch move; a repository the event created or deleted
::      reports nothing; repositories in name order;
::    - the route a web request wrote through, from its path;
::    - synchronize: a local pull request's head follows its source branch
::      in the event that moved it (not a deletion, not a closed one, never
::      a peer's), and a peer updates only its own open pull request.
::    - pull request labels: one update per label an edit adds or removes,
::      in name order, each with the labels after it, and no update for an
::      edit that changes nothing.  a head move and a label change in one
::      write give both.  the wire check %urgit-ci makes, the staleness
::      check against the record, and the labels route's decision for the
::      owner, a writer, a reader and the remote author, through the
::      production predicate can-write:git-access.
::  Every case names the verdict it expects; prints `passed=N of=M` and
::  ends in a loobean.
::
/-  ci, git
/+  ci-forge, git-access
:-  %say
|=  *
:-  %noun
=/  now  ~2026.10.16..12.00.00
=/  main  'refs/heads/main'
=/  pull-1=native-pull:git
  [1 ~nec 'demo' 'refs/heads/feature' main 'Add x' %open 0xd1 0xb1 ~ ~]
=/  blank=repository:git  *repository:git
=/  repo=repository:git
  %=  blank
    owner  ~zod
    head  main
    refs  (my ~[[main 0xb1] ['refs/tags/v1' 0xb1]])
  ==
=/  with-pull=repository:git  repo(native-pulls ~[pull-1])
=/  before=(map @t repository:git)  (my ~[['demo' repo]])
=/  report
  |=  [was=(map @t repository:git) is=(map @t repository:git)]
  ^-  (list action:ci)
  (forge-actions:ci-forge was is ~zod 'web editor' now)
=/  one
  |=  [was=repository:git is=repository:git]
  ^-  (list action:ci)
  (report (my ~[['demo' was]]) (my ~[['demo' is]]))
::  the one report's ref and pull updates, if there is exactly one
::
=/  refs-of
  |=  as=(list action:ci)
  ^-  (unit (list ref-update:ci))
  ?.  ?=([[%forge-events *] ~] as)  ~
  `refs.i.as
=/  pulls-of
  |=  as=(list action:ci)
  ^-  (unit (list pull-update:ci))
  ?.  ?=([[%forge-events *] ~] as)  ~
  `pulls.i.as
=/  ref-id
  |=  [ref=@t old=(unit oid:git) new=(unit oid:git) at=@da]
  ^-  @uv
  (sham [%ci-ref-event 'demo' ref old new at])
=/  moved=repository:git  repo(refs (~(put by refs.repo) main 0xc1))
=/  closed=native-pull:git  pull-1(state %closed)
=/  merged=native-pull:git  pull-1(state %merged)
::
=/  quiet=(list [name=@t expect=? got=?])
  :~  ['no write reports nothing' %.y =(~ (report before before))]
      ['a description reports nothing' %.y =(~ (one repo repo(description 'new words')))]
      :+  'a review comment reports nothing'  %.y
      =(~ (one with-pull repo(native-pulls ~[pull-1(comments ~[[1 ~nec 'looks good' now ~ ~ ~ %.n]])])))
      :+  'a scratch ref under refs/ci/ is %urgit-ci\'s own and reports nothing'  %.y
      =(~ (one repo repo(refs (~(put by refs.repo) 'refs/ci/run/0v1.aaaaa' 0xc1))))
      :+  'a repository the event created reports nothing'  %.y
      =(~ (report before (~(put by before) 'fresh' repo)))
      :+  'a repository the event deleted reports nothing'  %.y
      =(~ (report before ~))
  ==
=/  refs=(list [name=@t expect=? got=?])
  :~  :+  'a moved ref is one report: its old and new tips, actor, route, instant'  %.y
      .=  (one repo moved)
      :~  :*  %forge-events  'demo'
              ~[[(ref-id main `0xb1 `0xc1 now) main `0xb1 `0xc1]]
              ~  ~  ~zod  'web editor'  now
          ==  ==
      :+  'a created and a deleted ref, in name order'  %.y
      .=  %-  refs-of
          (one repo repo(refs (my ~[[main 0xb1] ['refs/heads/new' 0xc1]])))
      :-  ~
      :~  [(ref-id 'refs/heads/new' ~ `0xc1 now) 'refs/heads/new' ~ `0xc1]
          [(ref-id 'refs/tags/v1' `0xb1 ~ now) 'refs/tags/v1' `0xb1 ~]
      ==
      :+  'scratch refs are left out of a report that has real ones'  %.y
      .=  %-  refs-of
          (one repo moved(refs (~(put by refs.moved) 'refs/ci/run/0v1.aaaaa' 0xc1)))
      `~[[(ref-id main `0xb1 `0xc1 now) main `0xb1 `0xc1]]
      :+  'a redelivered event is the same id'  %.y
      =((one repo moved) (one repo moved))
      :+  'the same move at another instant is a new id'  %.y
      .=  %-  refs-of
          (forge-actions:ci-forge before (my ~[['demo' moved]]) ~zod 'web editor' (add now ~s1))
      `~[[(ref-id main `0xb1 `0xc1 (add now ~s1)) main `0xb1 `0xc1]]
      :+  'a default-branch move is reported'  %.y
      .=  (one repo repo(head 'refs/heads/trunk'))
      ~[[%forge-events 'demo' ~ ~ `[main 'refs/heads/trunk'] ~zod 'web editor' now]]
      :+  'repositories report in name order'  %.y
      .=  %+  turn
            %+  report
              (my ~[['b-repo' repo] ['a-repo' repo]])
            (my ~[['b-repo' moved] ['a-repo' moved]])
          |=(a=action:ci ?:(?=(%forge-events -.a) repo.a ''))
      ~['a-repo' 'b-repo']
  ==
=/  pull-id
  |=  [number=@ud action=@t head=oid:git]
  ^-  @uv
  (sham [%ci-pull-event 'demo' number action head now])
=/  pulls=(list [name=@t expect=? got=?])
  :~  :+  'a new open pull request is opened, with every fact'  %.y
      .=  (pulls-of (one repo with-pull))
      :-  ~
      :~  :*  (pull-id 1 'opened' 0xd1)  1  'opened'  0xd1  0xb1
              'refs/heads/feature'  main  ~nec  'demo'  'Add x'  %.n  ~  %open  ~  ~
          ==  ==
      :+  'open to closed is closed, not merged'  %.y
      =(`~[[(pull-id 1 'closed' 0xd1) 1 'closed' 0xd1 0xb1 'refs/heads/feature' main ~nec 'demo' 'Add x' %.n ~ %closed ~ ~]] (pulls-of (one with-pull with-pull(native-pulls ~[closed]))))
      :+  'a merge is closed and merged, with the target\'s tip before it'  %.y
      =/  as=(list action:ci)  (one with-pull moved(native-pulls ~[merged]))
      ?&  =(`~[[(pull-id 1 'closed' 0xd1) 1 'closed' 0xd1 0xb1 'refs/heads/feature' main ~nec 'demo' 'Add x' %.y `0xb1 %merged ~ ~]] (pulls-of as))
          =(`~[[(ref-id main `0xb1 `0xc1 now) main `0xb1 `0xc1]] (refs-of as))
      ==
      :+  'closed to open is reopened'  %.y
      =(`~[[(pull-id 1 'reopened' 0xd1) 1 'reopened' 0xd1 0xb1 'refs/heads/feature' main ~nec 'demo' 'Add x' %.n ~ %open ~ ~]] (pulls-of (one with-pull(native-pulls ~[closed]) with-pull)))
      :+  'an open pull request whose head moved is synchronize'  %.y
      =(`~[[(pull-id 1 'synchronize' 0xd2) 1 'synchronize' 0xd2 0xb1 'refs/heads/feature' main ~nec 'demo' 'Add x' %.n ~ %open ~ ~]] (pulls-of (one with-pull with-pull(native-pulls ~[pull-1(head 0xd2)]))))
      ['a pull request created closed reports nothing' %.y =(~ (one repo repo(native-pulls ~[closed])))]
      ['a merged pull request closed again reports nothing' %.y =(~ (one repo(native-pulls ~[merged]) repo(native-pulls ~[merged(state %closed)])))]
      :+  'transitions in number order'  %.y
      .=  %+  turn
            %+  fall
              (pulls-of (one repo repo(native-pulls ~[pull-1(number 9) pull-1(number 2)])))
            ~
          |=(p=pull-update:ci number.p)
      ~[2 9]
  ==
=/  routes=(list [name=@t expect=? got=?])
  :~  ['a Smart HTTP push with the write token' %.y =('smart-http push (write token)' (http-route:ci-forge ~['git' 'demo' 'git-receive-pack'] %.n))]
      ['a Smart HTTP push in a session' %.y =('smart-http push (session)' (http-route:ci-forge ~['git' 'demo' 'git-receive-pack'] %.y))]
      ['the web editor' %.y =('web editor' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'files' 'README.md'] %.y))]
      ['the default branch API' %.y =('default branch API' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'branches' 'default'] %.y))]
      ['the branch API' %.y =('branch API' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'branches'] %.y))]
      ['the tag API' %.y =('tag API' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'tags'] %.y))]
      ['a pull request merge' %.y =('pull request merge' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'pulls' '1' 'merge'] %.y))]
      ['a pull request state change' %.y =('pull request state' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'pulls' '1' 'state'] %.y))]
      ['a new pull request' %.y =('pull request API' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'pulls'] %.y))]
      ['another repository route' %.y =('web API' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'settings'] %.y))]
      ['anything else' %.y =('web request' (http-route:ci-forge ~['apps' 'other'] %.y))]
  ==
::  synchronize: a local pull request's head follows its source branch in
::  the event that moved it; a peer's follows only that peer's transfers
::
=/  local-pull=native-pull:git
  [3 ~zod 'demo' 'refs/heads/feature' main 'Local' %open 0xd1 0xb1 ~ ~]
=/  feature-at
  |=  [r=repository:git tip=oid:git]
  ^-  repository:git
  r(refs (~(put by refs.r) 'refs/heads/feature' tip))
=/  local=repository:git  (feature-at repo(native-pulls ~[local-pull]) 0xd1)
=/  followed
  |=  [was=repository:git is=repository:git]
  ^-  (map @t repository:git)
  (follow-source-branches:ci-forge (my ~[['demo' was]]) (my ~[['demo' is]]) ~zod)
=/  heads
  |=  m=(map @t repository:git)
  ^-  (list oid:git)
  (turn native-pulls:(~(got by m) 'demo') |=(p=native-pull:git head.p))
=/  pushed=repository:git  (feature-at local 0xd2)
=/  synced=(map @t repository:git)  (followed local pushed)
=/  sync-report=(list action:ci)
  (forge-actions:ci-forge (my ~[['demo' local]]) synced ~zod 'smart-http push (write token)' now)
=/  peer-open=native-pull:git  pull-1(number 4)
=/  sync=(list [name=@t expect=? got=?])
  :~  ['a local pull request\'s head follows its moved source branch' %.y =(~[0xd2] (heads synced))]
      :+  'and the one event reports the push and a synchronize'  %.y
      ?&  =(`~[[(ref-id 'refs/heads/feature' `0xd1 `0xd2 now) 'refs/heads/feature' `0xd1 `0xd2]] (refs-of sync-report))
          =(`~[[(sham [%ci-pull-event 'demo' 3 'synchronize' 0xd2 now]) 3 'synchronize' 0xd2 0xb1 'refs/heads/feature' main ~zod 'demo' 'Local' %.n ~ %open ~ ~]] (pulls-of sync-report))
      ==
      :+  'a branch the event did not move leaves a pull request as it was'  %.y
      =/  stale=repository:git  local(native-pulls ~[local-pull(head 0xd0)])
      =(~[0xd0] (heads (followed stale stale(refs (~(put by refs.stale) 'refs/heads/other' 0xe1)))))
      :+  'a deleted source branch leaves the head it had'  %.y
      =(~[0xd1] (heads (followed local local(refs (~(del by refs.local) 'refs/heads/feature')))))
      :+  'a closed pull request does not follow its branch'  %.y
      =/  shut=repository:git  local(native-pulls ~[local-pull(state %closed)])
      =(~[0xd1] (heads (followed shut (feature-at shut 0xd2))))
      :+  'a peer\'s pull request never follows a local branch of the same name'  %.y
      =/  theirs=repository:git  local(native-pulls ~[pull-1])
      =(~[0xd1] (heads (followed theirs (feature-at theirs 0xd2))))
      :+  'a peer updates only its own open pull request from that branch onto that target'  %.y
      =/  ps=(list native-pull:git)
        ~[closed peer-open pull-1(number 5, target-ref 'refs/heads/dev')]
      ?&  =(`peer-open (open-pull-from:ci-forge ps ~nec 'demo' 'refs/heads/feature' main))
          =(~ (open-pull-from:ci-forge ps ~bus 'demo' 'refs/heads/feature' main))
          =(~ (open-pull-from:ci-forge ps ~nec 'demo' 'refs/heads/other' main))
          =(~ (open-pull-from:ci-forge ~[closed] ~nec 'demo' 'refs/heads/feature' main))
      ==
  ==
::  ---- pull request labels ----
::
=/  label-id
  |=  [number=@ud action=@t label=@t head=oid:git]
  ^-  @uv
  (sham [%ci-pull-label-event 'demo' number action label head now])
=/  tagged=native-pull:git  pull-1(labels (silt ~['wip' 'bug']))
=/  with-tags=repository:git  repo(native-pulls ~[tagged])
::  one edit: add ci:fixtures and docs, remove wip
=/  edited=repository:git
  (with-pull-labels:ci-forge with-tags 1 (silt ~['bug' 'ci:fixtures' 'docs']))
=/  edit-list=(list pull-update:ci)  (fall (pulls-of (one with-tags edited)) ~)
=/  first-update=pull-update:ci  ?~(edit-list *pull-update:ci i.edit-list)
=/  label-update
  |=  [action=@t label=@t labels=(list @t) head=oid:git]
  ^-  pull-update:ci
  :*  (label-id 1 action label head)  1  action  head  0xb1  'refs/heads/feature'
      main  ~nec  'demo'  'Add x'  %.n  ~  %open  labels  `label
  ==
=/  long=@t  `@t`(fil 3 65 'x')
=/  edge=@t  `@t`(fil 3 64 'x')
=/  twenty=(list @t)
  :~  'a'  'b'  'c'  'd'  'e'  'f'  'g'  'h'  'i'  'j'
      'k'  'l'  'm'  'n'  'o'  'p'  'q'  'r'  's'  't'
  ==
::  the labels route's decision for a requester of repo-acl, through the
::  predicate the agent's repository-writable applies (no group seat)
=/  repo-acl=repository:git
  with-tags(writers (silt ~[~bus]), readers (silt ~[~sev]))
=/  decide
  |=  [who=@p labels=(unit (list @t))]
  ^-  (each (set @t) [status=@ud message=@t])
  =/  writable=?  (can-write:git-access owner.repo-acl writers.repo-acl %none who)
  (label-edit:ci-forge writable `tagged labels)
=/  refusal-403=(each (set @t) [status=@ud message=@t])
  :-  %|
  :-  403
  'only the repository owner and its writers may change pull request labels, because a label change can start CI'
=/  refusal-422=(each (set @t) [status=@ud message=@t])
  [%| 422 'labels must be an array of at most 20 non-empty strings, each at most 64 bytes']
=/  label-cases=(list [name=@t expect=? got=?])
  :~  :+  'one edit adding two labels and removing one is three updates, in name order'  %.y
      .=  edit-list
      :~  (label-update 'labeled' 'ci:fixtures' ~['bug' 'ci:fixtures' 'wip'] 0xd1)
          (label-update 'labeled' 'docs' ~['bug' 'ci:fixtures' 'docs' 'wip'] 0xd1)
          (label-update 'unlabeled' 'wip' ~['bug' 'ci:fixtures' 'docs'] 0xd1)
      ==
      :+  'two labels in one edit are two ids, and a redelivery is the same ids'  %.y
      ?&  ?=([* * * ~] edit-list)
          !=(id.i.edit-list id.i.t.edit-list)
          =(edit-list (fall (pulls-of (one with-tags edited)) ~))
      ==
      :+  'an edit that changes nothing reports nothing'  %.y
      =(~ (one with-tags (with-pull-labels:ci-forge with-tags 1 (silt ~['bug' 'wip']))))
      :+  'a head move and a label change in one write give both, the move first'  %.y
      .=  (pulls-of (one with-tags with-tags(native-pulls ~[tagged(head 0xd2, labels (silt ~['bug']))])))
      :-  ~
      :~  :*  (pull-id 1 'synchronize' 0xd2)  1  'synchronize'  0xd2  0xb1
              'refs/heads/feature'  main  ~nec  'demo'  'Add x'  %.n  ~  %open
              ~['bug' 'wip']  ~
          ==
          (label-update 'unlabeled' 'wip' ~['bug'] 0xd2)
      ==
      :+  'a new pull request is opened with its labels and no label update'  %.y
      .=  (pulls-of (one repo repo(native-pulls ~[tagged])))
      :-  ~
      :~  :*  (pull-id 1 'opened' 0xd1)  1  'opened'  0xd1  0xb1
              'refs/heads/feature'  main  ~nec  'demo'  'Add x'  %.n  ~  %open
              ~['bug' 'wip']  ~
          ==
      ==
      :+  'a label change on a closed pull request is reported with its state'  %.y
      =/  shut=native-pull:git  tagged(state %closed)
      .=  (pulls-of (one repo(native-pulls ~[shut]) repo(native-pulls ~[shut(labels (silt ~['bug']))])))
      :-  ~
      :~  :*  (label-id 1 'unlabeled' 'wip' 0xd1)  1  'unlabeled'  0xd1  0xb1
              'refs/heads/feature'  main  ~nec  'demo'  'Add x'  %.n  ~  %closed
              ~['bug']  `'wip'
          ==
      ==
      :+  'every update of the edit is well formed'  %.y
      (levy edit-list |=(p=pull-update:ci =(~ (pull-update-error:ci-forge p))))
      :+  'a labeled update with no label is refused, never read as no labels'  %.y
      =(`'a labeled update names no label' (pull-update-error:ci-forge first-update(label ~)))
      :+  'a labeled update whose labels leave out its label is refused'  %.y
      =(`'a labeled update for ci:fixtures does not list it' (pull-update-error:ci-forge first-update(labels ~['bug'])))
      :+  'an unlabeled update whose labels keep its label is refused'  %.y
      =/  u=pull-update:ci  first-update(action 'unlabeled')
      =(`'an unlabeled update for ci:fixtures still lists it' (pull-update-error:ci-forge u))
      :+  'unsorted, repeated, empty, long and too many labels are refused'  %.y
      ?&  =(`'the labels are not sorted' (pull-update-error:ci-forge first-update(labels ~['wip' 'ci:fixtures'])))
          =(`'the label bug is listed twice' (pull-update-error:ci-forge first-update(labels ~['bug' 'bug' 'ci:fixtures'])))
          =(`'a label is empty' (pull-update-error:ci-forge first-update(labels ~['' 'ci:fixtures'])))
          ?=(^ (pull-update-error:ci-forge first-update(labels ~[long])))
          =(`'more than 20 labels' (pull-update-error:ci-forge first-update(labels ['ci:fixtures' twenty])))
      ==
      :+  'another activity naming a label, or leaving another state, is refused'  %.y
      ?&  =(`'a synchronize update names a label' (pull-update-error:ci-forge first-update(action 'synchronize')))
          .=  `'a synchronize update leaves the pull request closed'
          (pull-update-error:ci-forge first-update(action 'synchronize', label ~, state %closed))
          =(`'merged does not match the pull request state' (pull-update-error:ci-forge first-update(merged %.y)))
          =(`'a label update names a tip before a merge' (pull-update-error:ci-forge first-update(target-before `0xb1)))
      ==
      :+  'a label update is fresh against the record that holds its label'  %.y
      =/  record=native-pull:git  (snag 0 native-pulls.edited)
      =(~ (pull-stale:ci-forge first-update record))
      :+  'a later edit that removed the label makes a labeled update stale'  %.y
      =/  record=native-pull:git  tagged
      =(`'pull request #1 no longer carries the label ci:fixtures: stale' (pull-stale:ci-forge first-update record))
      :+  'a later edit that put the label back makes an unlabeled update stale'  %.y
      =/  removal=pull-update:ci  ?~(edit-list *pull-update:ci (rear edit-list))
      =(`'pull request #1 carries the label wip again: stale' (pull-stale:ci-forge removal tagged))
      :+  'a label update on a closed pull request is fresh against a closed record'  %.y
      =/  record=native-pull:git  (snag 0 native-pulls.edited)
      =(~ (pull-stale:ci-forge first-update(state %closed) record(state %closed)))
      :+  'the labels route: the owner and a writer may change labels'  %.y
      ?&  =([%& (silt ~['ci:fixtures'])] (decide ~zod `~['ci:fixtures']))
          =([%& (silt ~['ci:fixtures'])] (decide ~bus `~['ci:fixtures']))
      ==
      :+  'a reader and the remote author who cannot write are refused with the reason'  %.y
      ?&  =(refusal-403 (decide ~sev `~['ci:fixtures']))
          =(refusal-403 (decide ~nec `~['ci:fixtures']))
      ==
      :+  'the limits: 20 labels of 64 bytes pass, 21 or a longer or empty one do not'  %.y
      ?&  =([%& (silt [edge (tail twenty)])] (decide ~zod `[edge (tail twenty)]))
          =(refusal-422 (decide ~zod `['u' twenty]))
          =(refusal-422 (decide ~zod `~[long]))
          =(refusal-422 (decide ~zod `~['']))
          =(refusal-422 (decide ~zod ~))
      ==
      :+  'repeated labels in one request are one label'  %.y
      =([%& (silt ~['bug'])] (decide ~zod `~['bug' 'bug']))
      :+  'a closed pull request takes labels, and a missing one is not found'  %.y
      ?&  =([%& (silt ~['bug'])] (label-edit:ci-forge %.y `tagged(state %closed) `~['bug']))
          =([%| 404 'pull request not found'] (label-edit:ci-forge %.y ~ `~['bug']))
      ==
      :+  'the labels route is named'  %.y
      =('pull request labels' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'demo' 'pulls' '1' 'labels'] %.y))
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld quiet refs pulls routes sync label-cases)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
