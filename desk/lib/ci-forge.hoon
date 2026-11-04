::  Forge events (Delivery 1C): what one of %urgit's events persisted,
::  for %urgit-ci.  %urgit diffs its repositories before and after every
::  event (on-poke, on-agent, on-arvo) and reports each repository's ref
::  moves, pull request transitions, pull request label changes and
::  default-branch change as one
::  %forge-events poke, so every route that persists a write — Smart HTTP,
::  the web editor, branch and tag routes, merges, peer pushes, landings,
::  linked-desk completions, imports — reports it exactly once, and a
::  refused or no-op write, which persists nothing, reports nothing.
::  Nothing here reads a request's claim.
::
::    the identity of a report is the facts and the instant of the event
::    that persisted them: one source operation is one id, its redelivery
::    the same id, and a legitimately repeated update a new one.  scratch
::    refs under refs/ci/ are %urgit-ci's own and never reported; nor are
::    the first refs of a repository the event created.
::
/-  ci, git
|%
++  scratch
  |=  ref=@t
  ^-  ?
  =('refs/ci/' (end [3 8] ref))
::
::  every repository that existed before the event and changed: its
::  report, or nothing when no ref, pull request or default branch moved
::
++  forge-actions
  |=  $:  before=(map @t repository:git)
          after=(map @t repository:git)
          actor=@p
          route=@t
          now=@da
      ==
  ^-  (list action:ci)
  ?:  =(before after)  ~
  %+  murn  (sort ~(tap by after) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
  |=  [name=@t repo=repository:git]
  ^-  (unit action:ci)
  =/  was=(unit repository:git)  (~(get by before) name)
  ?~  was  ~
  ?:  =(u.was repo)  ~
  =/  refs=(list ref-update:ci)  (ref-updates name refs.u.was refs.repo now)
  =/  pulls=(list pull-update:ci)
    (pull-updates name native-pulls.u.was native-pulls.repo refs.u.was now)
  =/  head=(unit [old=@t new=@t])
    ?:(=(head.u.was head.repo) ~ `[head.u.was head.repo])
  ?:  ?&(?=(~ refs) ?=(~ pulls) ?=(~ head))  ~
  `[%forge-events name refs pulls head actor route now]
::
::  every ref whose tip the event changed, created or deleted, in name
::  order, scratch refs aside
::
++  ref-updates
  |=  [repo=@t old=(map @t oid:git) new=(map @t oid:git) now=@da]
  ^-  (list ref-update:ci)
  ?:  =(old new)  ~
  =/  names=(list @t)
    (sort ~(tap in (~(uni in ~(key by old)) ~(key by new))) aor)
  %+  murn  names
  |=  ref=@t
  ^-  (unit ref-update:ci)
  ?:  (scratch ref)  ~
  =/  a=(unit oid:git)  (~(get by old) ref)
  =/  b=(unit oid:git)  (~(get by new) ref)
  ?:  =(a b)  ~
  `[(sham [%ci-ref-event repo ref a b now]) ref a b]
::
::  every native pull request transition and label change, by number.  a
::  new open pull request is opened.  open to closed or merged is closed
::  (merged with the target's tip before the merge, from the same event).
::  closed to open is reopened.  an open one whose head moved is
::  synchronize — its source branch moved (+follow-source-branches) or the
::  peer that opened it sent a new head (+open-pull-from).  then each
::  label the event added or removed (+pull-updates-of)
::
++  pull-updates
  |=  $:  repo=@t
          old=(list native-pull:git)
          new=(list native-pull:git)
          refs=(map @t oid:git)
          now=@da
      ==
  ^-  (list pull-update:ci)
  ?:  =(old new)  ~
  =/  was=(map @ud native-pull:git)
    (malt (turn old |=(p=native-pull:git [number.p p])))
  =/  ordered=(list native-pull:git)
    (sort new |=([a=native-pull:git b=native-pull:git] (lth number.a number.b)))
  =|  out=(list pull-update:ci)
  |-
  ^-  (list pull-update:ci)
  ?~  ordered  (flop out)
  =/  mine=(list pull-update:ci)
    (pull-updates-of repo (~(get by was) number.i.ordered) i.ordered refs now)
  $(ordered t.ordered, out (weld (flop mine) out))
::
::  one pull request's updates in one event.  its transition comes first,
::  with the labels it had before the event.  then each label name the
::  event added or removed is one labeled or unlabeled update, in name
::  order (aor), and each carries the labels after it: the event's
::  changes applied in that order.  a new pull request is opened with the
::  labels it has and no label update.  a label update's id names its
::  label, so two names in one event are two ids
::
++  pull-updates-of
  |=  [repo=@t prior=(unit native-pull:git) p=native-pull:git refs=(map @t oid:git) now=@da]
  ^-  (list pull-update:ci)
  =/  action=(unit @t)
    ?~  prior  ?:(=(%open state.p) `'opened' ~)
    ?:  =(state.u.prior state.p)
      ?:(?&(=(%open state.p) !=(head.u.prior head.p)) `'synchronize' ~)
    ?:  =(%open state.p)  `'reopened'
    ?:  =(%open state.u.prior)  `'closed'
    ~
  =/  merged=?  =(%merged state.p)
  =/  before=(set @t)  ?~(prior labels.p labels.u.prior)
  =/  transition=(list pull-update:ci)
    ?~  action  ~
    :_  ~
    :*  (sham [%ci-pull-event repo number.p u.action head.p now])
        number.p
        u.action
        head.p
        base.p
        source-ref.p
        target-ref.p
        source-ship.p
        source-repository.p
        title.p
        merged
        ?:(merged (~(get by refs) target-ref.p) ~)
        state.p
        (sorted-labels before)
        ~
    ==
  ?~  prior  transition
  =/  added=(set @t)  (~(dif in labels.p) labels.u.prior)
  =/  removed=(set @t)  (~(dif in labels.u.prior) labels.p)
  =/  changed=(list @t)  (sort ~(tap in (~(uni in added) removed)) aor)
  =/  current=(set @t)  labels.u.prior
  =|  acc=(list pull-update:ci)
  |-
  ^-  (list pull-update:ci)
  ?~  changed  (weld transition (flop acc))
  =/  name=@t  i.changed
  =/  adds=?  (~(has in added) name)
  =/  next=(set @t)  ?:(adds (~(put in current) name) (~(del in current) name))
  =/  act=@t  ?:(adds 'labeled' 'unlabeled')
  =/  update=pull-update:ci
    :*  (sham [%ci-pull-label-event repo number.p act name head.p now])
        number.p
        act
        head.p
        base.p
        source-ref.p
        target-ref.p
        source-ship.p
        source-repository.p
        title.p
        merged
        ~
        state.p
        (sorted-labels next)
        `name
    ==
  $(changed t.changed, current next, acc [update acc])
::
::  a label set as the wire and the payload carry it: sorted (aor)
::
++  sorted-labels
  |=  labels=(set @t)
  ^-  (list @t)
  (sort ~(tap in labels) aor)
::
::  the labels a pull request may carry, as an issue's: at most 20, each
::  non-empty and at most 64 bytes
::
++  max-labels  20
++  max-label-bytes  64
::
++  label-error
  |=  label=@t
  ^-  (unit @t)
  ?:  =('' label)  `'a label is empty'
  ?:  (gth (met 3 label) max-label-bytes)
    `(rap 3 ~['the label ' label ' is longer than 64 bytes'])
  ~
::
::  why a label list is not as the wire carries it, or ~: at most 20
::  labels, each well formed, sorted and distinct
::
++  labels-error
  |=  labels=(list @t)
  ^-  (unit @t)
  ?:  (gth (lent labels) max-labels)  `'more than 20 labels'
  =/  prior=(unit @t)  ~
  |-
  ^-  (unit @t)
  ?~  labels  ~
  =/  bad=(unit @t)  (label-error i.labels)
  ?^  bad  bad
  ?:  &(?=(^ prior) !(aor u.prior i.labels))  `'the labels are not sorted'
  ?:  =(prior `i.labels)  `(rap 3 ~['the label ' i.labels ' is listed twice'])
  $(labels t.labels, prior `i.labels)
::
::  why a pull request update from %urgit is not well formed, or ~.
::  %urgit-ci asks before it reads one, and refuses a malformed one with
::  the reason: a missing or inconsistent label is never read as no
::  labels.  its labels are well formed.  a labeled or unlabeled update
::  names its label, on the labels after a labeled one and off them after
::  an unlabeled one, and no tip before a merge.  no other update names a
::  label.  each native activity leaves the state it says, and merged is
::  the merged state
::
++  pull-update-error
  |=  p=pull-update:ci
  ^-  (unit @t)
  =/  bad=(unit @t)  (labels-error labels.p)
  ?^  bad  bad
  ?:  !=(merged.p =(%merged state.p))
    `'merged does not match the pull request state'
  ?:  |(=('labeled' action.p) =('unlabeled' action.p))
    ?~  label.p  `(rap 3 ~['a ' action.p ' update names no label'])
    =/  wrong=(unit @t)  (label-error u.label.p)
    ?^  wrong  wrong
    =/  listed=?  ?=(^ (find ~[u.label.p] labels.p))
    ?:  &(=('labeled' action.p) !listed)
      `(rap 3 ~['a labeled update for ' u.label.p ' does not list it'])
    ?:  &(=('unlabeled' action.p) listed)
      `(rap 3 ~['an unlabeled update for ' u.label.p ' still lists it'])
    ?^  target-before.p  `'a label update names a tip before a merge'
    ~
  ?^  label.p  `(rap 3 ~['a ' action.p ' update names a label'])
  ?:  ?&(|(=('opened' action.p) =('reopened' action.p) =('synchronize' action.p)) !=(%open state.p))
    `(rap 3 ~['a ' action.p ' update leaves the pull request ' state.p])
  ?:  &(=('closed' action.p) =(%open state.p))
    `'a closed update leaves the pull request open'
  ~
::
::  why a well formed pull request update is stale against the record
::  %urgit holds now, or ~: the record is in the state the activity leaves
::  it in, at the reported head, and a label change's label is on the
::  record (labeled) or off it (unlabeled).  a later edit that undid a
::  label change makes it stale
::
++  pull-stale
  |=  [p=pull-update:ci pr=native-pull:git]
  ^-  (unit @t)
  =/  number=@t  (crip (a-co:co number.p))
  =/  want=?(%open %merged %closed)
    ?^  label.p  state.p
    ?:  =('closed' action.p)  ?:(merged.p %merged %closed)
    %open
  ?.  =(want state.pr)
    `(rap 3 ~['pull request #' number ' is ' state.pr ' now, not what ' action.p ' leaves: stale'])
  ?.  =(head.p head.pr)
    `(rap 3 ~['pull request #' number '\'s head is not the reported one: stale'])
  ?~  label.p  ~
  =/  carries=?  (~(has in labels.pr) u.label.p)
  ?:  &(=('labeled' action.p) !carries)
    `(rap 3 ~['pull request #' number ' no longer carries the label ' u.label.p ': stale'])
  ?:  &(=('unlabeled' action.p) carries)
    `(rap 3 ~['pull request #' number ' carries the label ' u.label.p ' again: stale'])
  ~
::
::  a label edit, the labels route's and a peer's request alike.  the
::  requester must be able to write the repository (the owner, a writer
::  or a %write group seat), because a label change can start CI.  the
::  pull request's author is no exception.  the pull request must exist,
::  and the labels are at most 20, each non-empty and at most 64 bytes,
::  as an issue's.  a closed or merged pull request takes labels too: the
::  change is recorded and runs nothing.  an anonymous caller never gets
::  here: the API gate answers it 401
::
++  label-edit
  |=  [writable=? pull=(unit native-pull:git) labels=(unit (list @t))]
  ^-  (each (set @t) [status=@ud message=@t])
  ?.  writable
    :-  %|
    :-  403
    'only the repository owner and its writers may change pull request labels, because a label change can start CI'
  ?~  pull  [%| 404 'pull request not found']
  ?.  ?&  ?=(^ labels)
          (lte (lent u.labels) max-labels)
          (levy u.labels |=(label=@t ?=(~ (label-error label))))
      ==
    [%| 422 'labels must be an array of at most 20 non-empty strings, each at most 64 bytes']
  [%& (silt u.labels)]
::
::  a repository with one pull request's labels replaced: the write the
::  labels route and a writer's peer request persist, which +forge-actions
::  then reports as labeled and unlabeled updates
::
++  with-pull-labels
  |=  [repo=repository:git number=@ud labels=(set @t)]
  ^-  repository:git
  %=  repo
    native-pulls
      %+  turn  native-pulls.repo
      |=  p=native-pull:git
      ^-  native-pull:git
      ?.  =(number number.p)  p
      p(labels labels)
  ==
::
::  a local pull request's head follows its source branch (synchronize):
::  an open native pull request this ship opened from a branch of the same
::  repository takes the branch's new tip as its head when the event moved
::  that branch.  a deletion leaves the head as it was (the pull request
::  keeps the last head it had); a pull request a peer opened follows only
::  that peer's own updates (+open-pull-from).  who moved the branch is the
::  event's actor, never the pull request's author
::
++  follow-source-branches
  |=  [before=(map @t repository:git) after=(map @t repository:git) our=@p]
  ^-  (map @t repository:git)
  ?:  =(before after)  after
  %-  ~(urn by after)
  |=  [name=@t repo=repository:git]
  ^-  repository:git
  =/  was=(unit repository:git)  (~(get by before) name)
  ?~  was  repo
  ?:  =(refs.u.was refs.repo)  repo
  ?:  =(~ native-pulls.repo)  repo
  %=  repo
    native-pulls
      %+  turn  native-pulls.repo
      |=  p=native-pull:git
      ^-  native-pull:git
      ?.  ?&(=(%open state.p) =(our source-ship.p) =(name source-repository.p))  p
      =/  tip=(unit oid:git)  (~(get by refs.repo) source-ref.p)
      ?~  tip  p
      ?:  =(u.tip head.p)  p
      ::  only a move this event made: a branch it left alone keeps its pull
      ::  request as it was
      ?:  =((~(get by refs.u.was) source-ref.p) tip)  p
      p(head u.tip)
  ==
::
::  the open pull request a peer already opened from one source branch onto
::  one target, which a new transfer from the same ship (by Ames) updates
::  rather than opening another
::
++  open-pull-from
  |=  [pulls=(list native-pull:git) ship=@p repository=@t source-ref=@t target-ref=@t]
  ^-  (unit native-pull:git)
  |-
  ?~  pulls  ~
  ?:  ?&  =(%open state.i.pulls)
          =(ship source-ship.i.pulls)
          =(repository source-repository.i.pulls)
          =(source-ref source-ref.i.pulls)
          =(target-ref target-ref.i.pulls)
      ==
    `i.pulls
  $(pulls t.pulls)
::
::  the route a web request wrote through, from its path: the request is
::  authenticated (the session) or, for a push, carries the owner's write
::  token
::
++  http-route
  |=  [site=(list @t) authenticated=?]
  ^-  @t
  =/  who=@t  ?:(authenticated ' (session)' ' (write token)')
  ?:  ?=([%git @ %git-receive-pack ~] site)  (rap 3 ~['smart-http push' who])
  ?.  ?=([%apps %urgit %api %repository @ *] site)  'web request'
  =/  rest=(list @t)  t.t.t.t.t.site
  ?+  rest  'web API'
    [%files *]  'web editor'
    [%file *]  'web editor'
    [%branches %default ~]  'default branch API'
    [%branches *]  'branch API'
    [%tags *]  'tag API'
    [%pulls @ %merge ~]  'pull request merge'
    [%pulls @ %state ~]  'pull request state'
    [%pulls @ %labels ~]  'pull request labels'
    [%pulls ~]  'pull request API'
  ==
--
