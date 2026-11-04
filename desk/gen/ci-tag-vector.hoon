::  Private native vectors for tagged YAML. Authored here, not executed:
::  the parent must compile and run these on its fresh ship. The source
::  producer/async seams are separately pinned by taggedRevision.test.js.
/-  ci, git
/+  ci-tag, ci-forge, ci-trigger, git-codec
:-  %say
|=  *
:-  %noun
=/  put
  |=  [s=(map oid:git object:git) kind=object-kind:git data=octs]
  ^-  [oid:git (map oid:git object:git)]
  =/  id=oid:git  (object-oid:git-codec kind data)
  [id (~(put by s) id [kind data])]
=|  objects=(map oid:git object:git)
=^  tree  objects  (put objects %tree [0 0])
=^  commit  objects
  %:  put  objects  %commit
    %-  text:git-codec
    %+  rap
      3
    ~['tree ' (oid-text:git-codec tree) '\0aauthor A <a@example.com> 1 +0000\0acommitter A <a@example.com> 1 +0000\0a\0arelease\0a']
  ==
=^  tag  objects
  %:  put  objects  %tag
    %-  text:git-codec
    %+  rap
      3
    ~['object ' (oid-text:git-codec commit) '\0atype commit\0atag v1.2.3\0atagger A <a@example.com> 1 +0000\0a\0arelease\0a']
  ==
=^  outer  objects
  %:  put  objects  %tag
    %-  text:git-codec
    (rap 3 ~['object ' (oid-text:git-codec tag) '\0atype tag\0atag signed\0a\0aouter\0a'])
  ==
=^  broken  objects  (put objects %tag (text:git-codec 'not a tag'))
=^  bad-commit  objects  (put objects %commit (text:git-codec 'not a commit'))
=/  ref=@t  'refs/tags/v1.2.3'
=/  events=(list ref-update:ci)
  (ref-updates:ci-forge 'demo' ~ (my ~[[ref tag] ['refs/ci/test' commit]]) ~2026.10.17)
?>  =(1 (lent events))
?>  ?=(^ events)
=/  event=ref-update:ci  i.events
?>  =(`tag new.event)
=/  tags=filter:ci
  [%.n ~[['v*' %.n ~[[%lit 'v'] [%star ~]]] ['!v*-rc' %.y ~[[%lit 'v'] [%star ~] [%lit '-rc']]]]]
=/  paths=filter:ci
  [%.n ~[['src/**' %.n ~[[%lit 'src/'] [%globstar ~]]]]]
=/  push=trigger-event:ci  ['push' ~ ~ `tags `paths ~ %.n ~ 2 3]
=/  catalog=trigger-catalog:ci  [~[['release.yml' 'Release checks' ~[push] ~ ~]] ~]
=/  l=lock:ci
  [0x123 'demo' commit ~ ~2026.10.17 0v1 0 ~ ~ `catalog]
=/  different=lock:ci
  %=  l
    digest  0x456
    revision  0x999
    resolved  ~2026.10.18
    triggers  `[~[['today.yml' 'Default branch today' ~[push] ~ ~]] ~]
  ==
=/  c=candidate:ci
  =/  initial  *candidate:ci
  %=  initial
    id  0v2
    repo  'demo'
    ref  ref
    head  commit
    base  commit
    candidate  `commit
    baseline  `commit
    lock  ~
    actor  ~zod
    trust  %untrusted
    mode  %event
    incarnation  0v3
    generation  7
    trigger  [%event [id.event %push ref ~ `tag ~ ~ ~zod 'tag API' ~2026.10.17 '{}']]
    selected  ~
  ==
=/  bound  (bind-lock:ci-tag c l)
?>  ?=(%& -.bound)
=/  run=candidate:ci  p.bound
?>  ?=(^ selected.run)
?>  ?=(%event -.trigger.run)
=/  ignored  (bind-lock:ci-tag c(ref 'refs/tags/v1-rc') l)
?>  ?=(%& -.ignored)
=/  cycles=(map oid:git object:git)
  %+  ~(put by objects)
    0x888
  [%tag (text:git-codec 'object 0000000000000000000000000000000000000888\0atype tag\0a\0acycle')]
=/  refuses  |=(r=* ?=([%| *] r))
=/  cases=(list [name=@t ok=?])
  :~  ['lightweight commit' =([%& commit] (commit-at:ci-tag objects commit))]
      ['annotated commit through forge event' =([%& commit] (commit-at:ci-tag objects (need new.event)))]
      ['nested annotated commit' =([%& commit] (commit-at:ci-tag objects outer))]
      ['tree target refused' (refuses (commit-at:ci-tag objects tree))]
      ['missing object refused' (refuses (commit-at:ci-tag objects 0x777))]
      ['broken tag refused' (refuses (commit-at:ci-tag objects broken))]
      ['broken commit refused' (refuses (commit-at:ci-tag objects bad-commit))]
      ['cycle reaches bounded refusal' (refuses (commit-at:ci-tag cycles 0x888))]
      ['new tag has no hidden promotion requirement' =(~ (cached-lock:ci-tag ~ 'demo' commit))]
      ['different default YAML is not a lock for this revision' =(~ (cached-lock:ci-tag (my ~[[0x456 different]]) 'demo' commit))]
      ['own lock wins over newer default lock' =(`l (cached-lock:ci-tag (my ~[[0x123 l] [0x456 different]]) 'demo' commit))]
      ['unknown catalog must resolve again' =(~ (cached-lock:ci-tag (my ~[[0x123 l(triggers ~)]]) 'demo' commit))]
      ['selected workflow comes from tagged catalog' =(~['release.yml'] (selected-workflows:ci-trigger outcomes.u.selected.run))]
      ['tag path filters do not exclude it' (ready:ci-tag run)]
      ['excluded tag does not become ready' !(ready:ci-tag p.ignored)]
      ['excluded tag records selection and skip' &(?=(^ selected.p.ignored) =(%skipped status.p.ignored))]
      ['event mode preserved' =(%event mode.run)]
      ['actor and untrusted class preserved' =([actor trust]:c [actor trust]:run)]
      ['source workflow event and policy preserved' =([head candidate baseline trigger incarnation generation]:c [head candidate baseline trigger incarnation generation]:run)]
      ['initially missing lock not ready' !(ready:ci-tag c)]
      ['completion without catalog refuses' (refuses (bind-lock:ci-tag c l(triggers ~)))]
      ['completion of wrong revision refuses' (refuses (bind-lock:ci-tag c different))]
      ['completion of another repository refuses' (refuses (bind-lock:ci-tag c l(repo 'other')))]
      ['completion replay keeps exact candidate' =([%& run] (bind-lock:ci-tag run l))]
      ['another completed lock cannot replace admitted lock' (refuses (bind-lock:ci-tag run l(digest 0x456)))]
      ['required candidate cannot acquire tag authority' (refuses (bind-lock:ci-tag c(mode %required) l))]
      ['branch cannot acquire tag authority' (refuses (bind-lock:ci-tag c(ref 'refs/heads/master') l))]
      ['no raw tag object in checkout' =(candidate.run `commit)]
      ['raw annotated event identity kept' =(after.run-event.trigger.run `tag)]
  ==
=/  failed  (skim cases |=([name=@t ok=?] !ok))
~&  (turn cases |=([name=@t ok=?] [name ok]))
~&  [%passed (sub (lent cases) (lent failed)) %of (lent cases)]
=(~ failed)
