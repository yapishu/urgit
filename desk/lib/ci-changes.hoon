::  Changed paths (Delivery 1C): the complete, bounded set of paths an
::  event changed, computed from the repository's own objects (%urgit's
::  ci-changes peeks), never from a request and never from the capped
::  browser diff (git-json repository-diff-json).  Every answer is the
::  sorted path set or why it is unavailable — a missing or malformed
::  object, or a bound exceeded — which a path filter never reads as no
::  match (lib/ci-trigger decide).
::
::    a push to an existing ref compares the old and new tips' trees (the
::    captured reference's two-dot diff); a new ref compares its tip with
::    the first parent of the deepest commit it brought (following first
::    parents from the tip while the commit is reachable from no other
::    branch or tag; the empty tree for a root); a pull request compares
::    its head with each best merge base of head and target (three-dot),
::    the union for several, the empty tree for none.  a rename is a
::    deletion and an addition: both paths changed.
::
/-  git
/+  git-clay, git-graph
|%
++  max-paths  10.000
++  max-trees  20.000
++  max-commits  10.000
++  max-walk  50.000
::
+$  change-set  (each (list @t) @t)
::
++  oid-hex
  |=  =oid:git
  ^-  @t
  (crip ((x-co:co 40) oid))
::
::  a commit's tree and parents, or why not
::
++  commit-of
  |=  [objects=(map oid:git object:git) commit=oid:git]
  ^-  (each [tree=oid:git parents=(list oid:git)] @t)
  =/  found=(unit object:git)  (~(get by objects) commit)
  ?~  found  [%| (rap 3 ~['commit ' (oid-hex commit) ' is missing from the store'])]
  ?.  =(%commit kind.u.found)  [%| (rap 3 ~[(oid-hex commit) ' is not a commit'])]
  =/  parts=(unit [tree=oid:git parents=(list oid:git)])  (commit-parts:git-graph data.u.found)
  ?~  parts  [%| (rap 3 ~['commit ' (oid-hex commit) ' is malformed'])]
  [%& u.parts]
::
::  a tree's entries by name, or why not
::
++  entries-of
  |=  [objects=(map oid:git object:git) tree=oid:git]
  ^-  (each (map @t tree-entry:git-clay) @t)
  =/  found=(unit object:git)  (~(get by objects) tree)
  ?~  found  [%| (rap 3 ~['tree ' (oid-hex tree) ' is missing from the store'])]
  ?.  =(%tree kind.u.found)  [%| (rap 3 ~[(oid-hex tree) ' is not a tree'])]
  =/  parsed=(unit (list tree-entry:git-clay))  (parse-tree:git-clay data.u.found)
  ?~  parsed  [%| (rap 3 ~['tree ' (oid-hex tree) ' is malformed'])]
  [%& (malt (turn u.parsed |=(e=tree-entry:git-clay [name.e e])))]
::
++  is-tree
  |=  mode=@t
  ^-  ?
  =('40000' mode)
::
++  join-path
  |=  [prefix=@t name=@t]
  ^-  @t
  ?:(=('' prefix) name (rap 3 ~[prefix '/' name]))
::
::  the diff walk's running state: the paths found, how many, and the
::  trees read (counted as they come: a set's size is a walk of its own)
::
+$  walk  [paths=(set @t) count=@ud trees=@ud]
::
++  over
  |=  w=walk
  ^-  (unit @t)
  ?:  (gth count.w max-paths)
    `(rap 3 ~['more than ' (crip (a-co:co max-paths)) ' paths changed'])
  ?:  (gth trees.w max-trees)
    `(rap 3 ~['more than ' (crip (a-co:co max-trees)) ' trees to compare'])
  ~
::
::  every path two trees differ at (~ is the empty tree): an entry with
::  the same mode and object on both sides is unchanged and not read
::
++  tree-diff
  |=  [objects=(map oid:git object:git) from=(unit oid:git) to=(unit oid:git)]
  ^-  change-set
  =/  done=(each walk @t)  (diff-at objects from to '' [~ 0 0])
  ?:  ?=(%| -.done)  [%| p.done]
  [%& (sort ~(tap in paths.p.done) aor)]
::
++  diff-at
  |=  [objects=(map oid:git object:git) from=(unit oid:git) to=(unit oid:git) prefix=@t w=walk]
  ^-  (each walk @t)
  ?:  =(from to)  [%& w]
  =.  trees.w  (add trees.w (add ?~(from 0 1) ?~(to 0 1)))
  =/  bound=(unit @t)  (over w)
  ?^  bound  [%| u.bound]
  =/  a=(each (map @t tree-entry:git-clay) @t)  ?~(from [%& ~] (entries-of objects u.from))
  ?:  ?=(%| -.a)  [%| p.a]
  =/  b=(each (map @t tree-entry:git-clay) @t)  ?~(to [%& ~] (entries-of objects u.to))
  ?:  ?=(%| -.b)  [%| p.b]
  =/  names=(list @t)
    (sort ~(tap in (~(uni in ~(key by p.a)) ~(key by p.b))) aor)
  |-
  ?~  names  [%& w]
  =/  path=@t  (join-path prefix i.names)
  =/  old=(unit tree-entry:git-clay)  (~(get by p.a) i.names)
  =/  new=(unit tree-entry:git-clay)  (~(get by p.b) i.names)
  ?:  ?&(?=(^ old) ?=(^ new) =(mode.u.old mode.u.new) =(oid.u.old oid.u.new))
    $(names t.names)
  ::  the tree sides are walked (a whole subtree when the other side is not
  ::  a tree); a non-tree side is the path itself
  =/  old-tree=(unit oid:git)  ?.(?&(?=(^ old) (is-tree mode.u.old)) ~ `oid.u.old)
  =/  new-tree=(unit oid:git)  ?.(?&(?=(^ new) (is-tree mode.u.new)) ~ `oid.u.new)
  =/  leaf=?
    ?|  ?&(?=(^ old) !(is-tree mode.u.old))
        ?&(?=(^ new) !(is-tree mode.u.new))
    ==
  =?  w  leaf  w(paths (~(put in paths.w) path), count +(count.w))
  =/  nested=(each walk @t)
    ?:  ?&(?=(~ old-tree) ?=(~ new-tree))  [%& w]
    (diff-at objects old-tree new-tree path w)
  ?:  ?=(%| -.nested)  [%| p.nested]
  =/  bound=(unit @t)  (over p.nested)
  ?^  bound  [%| u.bound]
  $(names t.names, w p.nested)
::
::  two commits' trees compared (~ is no commit: the empty tree)
::
++  commit-diff
  |=  [objects=(map oid:git object:git) from=(unit oid:git) to=oid:git]
  ^-  change-set
  =/  b=(each [tree=oid:git parents=(list oid:git)] @t)  (commit-of objects to)
  ?:  ?=(%| -.b)  [%| p.b]
  ?~  from  (tree-diff objects ~ `tree.p.b)
  =/  a=(each [tree=oid:git parents=(list oid:git)] @t)  (commit-of objects u.from)
  ?:  ?=(%| -.a)  [%| p.a]
  (tree-diff objects `tree.p.a `tree.p.b)
::
::  the commit a ref's object stands for: itself, or an annotated tag's
::  target, peeled (at most eight tags deep); ~ for a tree or a blob, which
::  stands for no commit
::
++  peel
  |=  [objects=(map oid:git object:git) =oid:git]
  ^-  (each (unit oid:git) @t)
  =/  depth=@ud  0
  |-
  =/  found=(unit object:git)  (~(get by objects) oid)
  ?~  found  [%| (rap 3 ~['object ' (oid-hex oid) ' is missing from the store'])]
  ?:  =(%commit kind.u.found)  [%& `oid]
  ?.  =(%tag kind.u.found)  [%& ~]
  ?:  (gte depth 8)  [%| 'a chain of tags is more than eight deep']
  =/  target=(unit (list oid:git))  (text-object-dependencies:git-graph data.u.found %.y)
  ?.  ?=([~ [* ~]] target)  [%| (rap 3 ~['tag ' (oid-hex oid) ' is malformed'])]
  $(oid i.u.target, depth +(depth))
::
::  A validated commit target for an automatic tag run.
++  commit-at
  |=  [objects=(map oid:git object:git) object=oid:git]
  ^-  (each oid:git @t)
  =/  peeled  (peel objects object)
  ?:  ?=(%| -.peeled)  [%| p.peeled]
  ?~  p.peeled  [%| 'the tag target is not a commit']
  =/  checked  (commit-of objects u.p.peeled)
  ?:  ?=(%| -.checked)  [%| p.checked]
  [%& u.p.peeled]
::
::  every commit reachable from .roots (each peeled; a tree or blob root
::  stands for none) by parent links, at most .bound of them, or why not
::
++  ancestors
  |=  [objects=(map oid:git object:git) tips=(list oid:git) bound=@ud]
  ^-  (each (set oid:git) @t)
  =/  peeled=(each (list oid:git) @t)
    =|  out=(list oid:git)
    |-
    ?~  tips  [%& out]
    =/  one=(each (unit oid:git) @t)  (peel objects i.tips)
    ?:  ?=(%| -.one)  [%| p.one]
    $(tips t.tips, out ?~(p.one out [u.p.one out]))
  ?:  ?=(%| -.peeled)  [%| p.peeled]
  =/  pending=(list oid:git)  p.peeled
  =|  seen=(set oid:git)
  =/  count=@ud  0
  |-
  ?~  pending  [%& seen]
  ?:  (~(has in seen) i.pending)  $(pending t.pending)
  ?:  (gte count bound)
    [%| (rap 3 ~['the history walk exceeds ' (crip (a-co:co bound)) ' commits'])]
  =/  c=(each [tree=oid:git parents=(list oid:git)] @t)  (commit-of objects i.pending)
  ?:  ?=(%| -.c)  [%| p.c]
  %=  $
    pending  (weld parents.p.c t.pending)
    seen  (~(put in seen) i.pending)
    count  +(count)
  ==
::
::  a push of a ref: two-dot from the old tip, or for a new ref from the
::  first parent of the deepest commit it brought.  .others are the tips of
::  every other branch and tag
::
++  push-changes
  |=  [objects=(map oid:git object:git) old=(unit oid:git) new=oid:git others=(list oid:git)]
  ^-  change-set
  ?^  old  (commit-diff objects old new)
  =/  known=(each (set oid:git) @t)  (ancestors objects others max-walk)
  ?:  ?=(%| -.known)  [%| (rap 3 ~['the commits a new ref brought cannot be told apart: ' p.known])]
  ?:  (~(has in p.known) new)  [%& ~]
  =/  at=oid:git  new
  =/  steps=@ud  0
  |-
  ?:  (gte steps max-commits)
    [%| (rap 3 ~['the new ref brought more than ' (crip (a-co:co max-commits)) ' commits'])]
  =/  c=(each [tree=oid:git parents=(list oid:git)] @t)  (commit-of objects at)
  ?:  ?=(%| -.c)  [%| p.c]
  ?~  parents.p.c  (commit-diff objects ~ new)
  ?:  (~(has in p.known) i.parents.p.c)  (commit-diff objects `i.parents.p.c new)
  $(at i.parents.p.c, steps +(steps))
::
::  the best common ancestors of two commits: the common ancestors that
::  are no parent of another common ancestor (the common set is closed
::  under parents, so these are exactly the ones no other is above)
::
++  merge-bases
  |=  [objects=(map oid:git object:git) a=oid:git b=oid:git]
  ^-  (each (list oid:git) @t)
  =/  left=(each (set oid:git) @t)  (ancestors objects ~[a] max-commits)
  ?:  ?=(%| -.left)  [%| p.left]
  =/  right=(each (set oid:git) @t)  (ancestors objects ~[b] max-commits)
  ?:  ?=(%| -.right)  [%| p.right]
  =/  common=(set oid:git)  (~(int in p.left) p.right)
  =/  below=(set oid:git)
    %+  roll  ~(tap in common)
    |=  [c=oid:git acc=(set oid:git)]
    =/  parts=(each [tree=oid:git parents=(list oid:git)] @t)  (commit-of objects c)
    ?:  ?=(%| -.parts)  acc
    (~(gas in acc) parents.p.parts)
  [%& (sort ~(tap in (~(dif in common) below)) lth)]
::
::  a pull request's paths: three-dot from each best merge base of the head
::  and the target tip to the head, the union over several bases, from the
::  empty tree when the histories share none
::
++  pull-changes
  |=  [objects=(map oid:git object:git) head=oid:git target=oid:git]
  ^-  change-set
  =/  bases=(each (list oid:git) @t)  (merge-bases objects head target)
  ?:  ?=(%| -.bases)  [%| p.bases]
  ?~  p.bases  (commit-diff objects ~ head)
  =/  rest=(list oid:git)  p.bases
  =|  union=(set @t)
  |-
  ?~  rest  [%& (sort ~(tap in union) aor)]
  =/  one=change-set  (commit-diff objects `i.rest head)
  ?:  ?=(%| -.one)  [%| p.one]
  =/  next=(set @t)  (~(gas in union) p.one)
  ?:  (gth ~(wyt in next) max-paths)
    [%| (rap 3 ~['more than ' (crip (a-co:co max-paths)) ' paths changed'])]
  $(rest t.rest, union next)
--
