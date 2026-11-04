::  ci-writer-vector: the pure rules every ref writer's CI gate applies
::  (Q5, lib/ci-writer), on offline fixtures.  it covers the ref changes
::  an import, a fork refresh or a publication makes (ref-changes), what
::  the gate makes of them given what %urgit-ci answers per ref (classify,
::  refusal), and whether an object contains a tip (commit-contains).  no
::  ship and no network: GitHub's and a fork origin's refs are fixture
::  maps, and %urgit-ci's answers are fixture gates.  every case names the
::  verdict it expects; the intentionally FALSE cases (expect %.n) are the
::  ones where a rule must refuse, and the generator fails if any of them
::  is accepted.  prints `passed=N of=M` and ends in a loobean.
::
/-  git
/+  ci-writer, git-codec
:-  %say
|=  *
:-  %noun
::  tips, as the forge stores them
::
=/  a=oid:git  0xaaaa.0000.0000.0000.0000.0000.0000.0000.0000.0001
=/  a2=oid:git  0xaaaa.0000.0000.0000.0000.0000.0000.0000.0000.0002
=/  b=oid:git  0xbbbb.0000.0000.0000.0000.0000.0000.0000.0000.0001
=/  g=oid:git  0xcccc.0000.0000.0000.0000.0000.0000.0000.0000.0001
=/  k=oid:git  0xdddd.0000.0000.0000.0000.0000.0000.0000.0000.0001
=/  n=oid:git  0xeeee.0000.0000.0000.0000.0000.0000.0000.0000.0001
=/  main=@t  'refs/heads/main'
=/  dev=@t  'refs/heads/dev'
::  %urgit-ci's answers: a set of protected refs, or an outage
::
=/  protects
  |=  refs=(list @t)
  |=  ref=@t
  ^-  (each ? @t)
  [%& (~(has in (silt refs)) ref)]
=/  outage-text=@t
  'ci: %urgit-ci is not running; protected-ref writes are refused until it is'
=/  outage
  |=  ref=@t
  ^-  (each ? @t)
  [%| outage-text]
::  a GitHub update: the repository's refs, what GitHub advertises, and
::  the refs the update would install (local-only refs kept)
::
=/  existing=(map @t oid:git)  (malt ~[[main a] [dev b] ['refs/heads/keep' k]])
=/  advertised=(map @t oid:git)  (malt ~[[main a2] [dev b] ['refs/heads/new' n]])
=/  installed=(map @t oid:git)  (~(uni by existing) advertised)
::  a fork refresh: the fork's refs and the origin's, installed whole
::
=/  fork=(map @t oid:git)  (malt ~[[main a] ['refs/heads/gone' g]])
=/  origin=(map @t oid:git)  (malt ~[[main a2]])
::  commits, canonical, for commit-contains: c1 <- c2 <- c3; side is a
::  root; merge merges c3 and side; lone is unrelated; the orphan names a
::  parent that is missing
::
=/  make
  |=  [parents=(list oid:git) message=@t]
  ^-  [oid:git object:git]
  =/  lines=(list @t)
    ;:  weld
      ~['tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904']
      (turn parents |=(p=oid:git (cat 3 'parent ' (oid-text:git-codec p))))
      ~['author x <x> 0 +0000' 'committer x <x> 0 +0000' '' message]
    ==
  =/  body=@t  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
  =/  data=octs  (text:git-codec body)
  [(object-oid:git-codec %commit data) [%commit data]]
=/  c1  (make ~ 'c1')
=/  c2  (make ~[-.c1] 'c2')
=/  c3  (make ~[-.c2] 'c3')
=/  side  (make ~ 'side')
=/  merge  (make ~[-.c3 -.side] 'merge')
=/  lone  (make ~ 'lone')
=/  orphan  (make ~[0xbeef] 'orphan')
=/  objects=(map oid:git object:git)  (malt ~[c1 c2 c3 side merge lone orphan])
=/  contains
  |=  [commit=oid:git ancestor=oid:git]
  (commit-contains:ci-writer objects commit ancestor)
=/  cases=(list [name=@t expect=? got=?])
  :~  ::  ref-changes
      ['identical maps change nothing' %.y =(~ (ref-changes:ci-writer existing existing))]
      :*  'a GitHub update changes the fast-forward and the new branch, not the kept ones'
          %.y
          .=  (silt (ref-changes:ci-writer existing installed))
          (silt `(list receive-command:git)`~[[`a `a2 main] [~ `n 'refs/heads/new']])
      ==
      :*  'a fork refresh changes the advanced branch and deletes the one the origin lacks'
          %.y
          .=  (silt (ref-changes:ci-writer fork origin))
          (silt `(list receive-command:git)`~[[`a `a2 main] [`g ~ 'refs/heads/gone']])
      ==
      :*  'an install creates every ref'
          %.y
          .=  (silt (ref-changes:ci-writer ~ origin))
          (silt `(list receive-command:git)`~[[~ `a2 main]])
      ==
      ::  classify
      ['no change is open' %.y =([%open ~] (classify:ci-writer ~ (protects ~[main])))]
      ['an unprotected change is open' %.y =([%open ~] (classify:ci-writer ~[[`b `a dev]] (protects ~[main])))]
      ['an unchanged protected ref is not asked about, even in an outage' %.y =([%open ~] (classify:ci-writer ~[[`a `a main]] outage))]
      ['a protected update is staged against its tip' %.y =([%stage ~[[main a2 a]]] (classify:ci-writer ~[[`a `a2 main]] (protects ~[main])))]
      :*  'a protected deletion is refused'
          %.y
          .=  [%refuse 409 'ci-protected ref cannot be deleted: refs/heads/main']
          (classify:ci-writer ~[[`a ~ main]] (protects ~[main]))
      ==
      :*  'a protected creation is refused: it has no tip to stage against'
          %.y
          .=  [%refuse 409 'ci-protected ref has no tip to stage a candidate against: refs/heads/main']
          (classify:ci-writer ~[[~ `a main]] (protects ~[main]))
      ==
      ['an outage refuses an unprotected change too' %.y =([%refuse 503 outage-text] (classify:ci-writer ~[[`b `a dev]] outage))]
      :*  'every protected update of one write is staged, in order'
          %.y
          .=  [%stage ~[[main a2 a] [dev a b]]]
          (classify:ci-writer ~[[`a `a2 main] [`b `a dev]] (protects ~[main dev]))
      ==
      :*  'beside an unprotected change only the protected update is staged'
          %.y
          .=  [%stage ~[[main a2 a]]]
          (classify:ci-writer ~[[`b `a dev] [`a `a2 main]] (protects ~[main]))
      ==
      :*  'a protected deletion anywhere refuses the whole write'
          %.y
          .=  [%refuse 409 'ci-protected ref cannot be deleted: refs/heads/gone']
          (classify:ci-writer ~[[`a `a2 main] [`g ~ 'refs/heads/gone']] (protects ~[main 'refs/heads/gone']))
      ==
      :*  'GitHub update fixture: the protected fast-forward is staged, the new branch is not'
          %.y
          .=  [%stage ~[[main a2 a]]]
          (classify:ci-writer (ref-changes:ci-writer existing installed) (protects ~[main]))
      ==
      :*  'fork refresh fixture: a protected branch the origin lacks refuses the refresh'
          %.y
          .=  [%refuse 409 'ci-protected ref cannot be deleted: refs/heads/gone']
          (classify:ci-writer (ref-changes:ci-writer fork origin) (protects ~['refs/heads/gone']))
      ==
      :*  'fork install fixture: a protection left on the name refuses the install'
          %.y
          .=  [%refuse 409 'ci-protected ref has no tip to stage a candidate against: refs/heads/main']
          (classify:ci-writer (ref-changes:ci-writer ~ origin) (protects ~[main]))
      ==
      ['intentionally false: a protected update is never open' %.n =([%open ~] (classify:ci-writer ~[[`a `a2 main]] (protects ~[main])))]
      ['intentionally false: a protected deletion is never open' %.n =([%open ~] (classify:ci-writer ~[[`a ~ main]] (protects ~[main])))]
      ['intentionally false: an outage is never open for a real change' %.n =([%open ~] (classify:ci-writer ~[[`b `a dev]] outage))]
      ['intentionally false: a protected import is never open' %.n =([%open ~] (classify:ci-writer (ref-changes:ci-writer existing installed) (protects ~[main])))]
      ::  refusal
      ['refusal lets an open write through' %.y =(~ (refusal:ci-writer [%open ~]))]
      ['refusal keeps a refusal' %.y =(`[503 'x'] (refusal:ci-writer [%refuse 503 'x']))]
      :*  'refusal turns a stage into a refusal naming the ref'
          %.y
          .=  `[409 'ci-protected ref advances only by landing a CI candidate or a recorded override: refs/heads/main']
          (refusal:ci-writer [%stage ~[[main a2 a]]])
      ==
      ['intentionally false: a stage is never let through a writer that cannot stage' %.n =(~ (refusal:ci-writer [%stage ~[[main a2 a]]]))]
      ::  commit-contains
      ['a commit contains itself' %.y (contains -.c3 -.c3)]
      ['a descendant contains its ancestor' %.y (contains -.c3 -.c1)]
      ['a merge contains its second parent' %.y (contains -.merge -.side)]
      ['a merge contains the ancestors of its first parent' %.y (contains -.merge -.c1)]
      ['intentionally false: an ancestor contains its descendant' %.n (contains -.c1 -.c3)]
      ['intentionally false: an unrelated commit is contained' %.n (contains -.lone -.c1)]
      ['intentionally false: a missing commit contains anything' %.n (contains 0xdead -.c1)]
      ['intentionally false: a walk through a missing parent finds the tip' %.n (contains -.orphan -.c1)]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%false-assertions-refused (lent (skim cases |=([* expect=? got=?] &(!expect !got)))) %of (lent (skim cases |=([* expect=? *] !expect)))]
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
