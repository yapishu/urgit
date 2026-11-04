::  Ordinary automatic tags use their own commit's workflows. No promotion
::  is created. The catalog and dependency lock must name that exact commit.
/-  ci, git
/+  ci-changes, ci-trigger, git-codec
|%
++  tag-ref
  |=  ref=@t
  ^-  ?
  =('refs/tags/' (end [3 10] ref))
::
++  commit-at
  |=  [objects=(map oid:git object:git) object=oid:git]
  ^-  (each oid:git @t)
  (commit-at:ci-changes objects object)
::
::  Read once at admission. An unknown catalog requires a fresh resolve.
++  cached-lock
  |=  [locks=(map @ux lock:ci) repo=@t revision=oid:git]
  ^-  (unit lock:ci)
  =/  matches=(list lock:ci)
    %+  skim  ~(val by locks)
    |=  l=lock:ci
    &(=(repo repo.l) =(revision revision.l) ?=(^ triggers.l))
  =.  matches
    %+  sort  matches
    |=  [a=lock:ci b=lock:ci]
    ?:  =(resolved.a resolved.b)  (lth digest.a digest.b)
    (gth resolved.a resolved.b)
  ?~(matches ~ `i.matches)
::
::  Bind once, before planning. Ref movement cannot change these inputs.
++  bind-lock
  |=  [c=candidate:ci l=lock:ci]
  ^-  (each candidate:ci @t)
  ?.  ?&  =(%event mode.c)  ?=(%event -.trigger.c)  (tag-ref ref.c)
          =(%push kind.run-event.trigger.c)
          =(`head.c candidate.c)  =(`head.c baseline.c)
          =(repo.c repo.l)  =(head.c revision.l)
      ==
    [%| 'the tagged source, workflow revision and lock do not agree']
  ?~  triggers.l  [%| 'the tagged revision lock has no trigger catalog']
  ?^  selected.c
    ?:  =(`digest.l lock.c)  [%& c]
    [%| 'the admitted tag run already binds another lock']
  =/  outcomes=(list workflow-selection:ci)
    (select-push:ci-trigger u.triggers.l ref.c ~)
  =/  chosen=(list @t)  (selected-workflows:ci-trigger outcomes)
  =/  basis=@t
    (rap 3 ~['tagged revision ' (oid-text:git-codec head.c) ' for ' ref.c])
  =/  why=(unit @t)
    ?^  chosen  ~
    ?:  (lien outcomes |=(o=workflow-selection:ci =(%error verdict.o)))
      `'refused: the tagged workflow triggers contain errors (see Selection)'
    `'filtered out: no workflow in the tagged revision selects this tag'
  :-  %&
  %=  c
    lock  `digest.l
    selected  `[basis outcomes ~]
    status  ?^(chosen %pending %skipped)
    verdict-reason  why
  ==
::
++  ready
  |=  c=candidate:ci
  ^-  ?
  ?&  =(%event mode.c)  ?=(%event -.trigger.c)  (tag-ref ref.c)
      =(`head.c candidate.c)  =(`head.c baseline.c)
      ?=(^ lock.c)  ?=(^ selected.c)
      ?=(^ (selected-workflows:ci-trigger outcomes.u.selected.c))
  ==
--
