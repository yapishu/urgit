::  Candidate materialization: the exact object %urgit-ci tests and %urgit
::  lands.  a fast-forward candidate is the source head itself; a divergent
::  source is merged onto the destination tip with the same three-way merge
::  the pull-request path uses.  nothing here moves a ref.
::
/-  git
/+  git-graph, git-tree
|%
+$  outcome
  $%  [%ready candidate=oid:git objects=(map oid:git object:git)]
      [%conflict reason=@t]
  ==
::
++  commit-parents
  |=  [objects=(map oid:git object:git) commit=oid:git]
  ^-  (unit (list oid:git))
  =/  found=(unit object:git)  (~(get by objects) commit)
  ?~  found  ~
  ?.  =(%commit kind.u.found)  ~
  =/  parts=(unit [tree=oid:git parents=(list oid:git)])
    (commit-parts:git-graph data.u.found)
  ?~  parts  ~
  `parents.u.parts
::
::  every commit reachable from .root through parent links, .root included;
::  ~ when a commit on the way is missing or malformed
::
++  commit-ancestors
  |=  [objects=(map oid:git object:git) root=oid:git]
  ^-  (unit (set oid:git))
  =/  pending=(list oid:git)  ~[root]
  =/  seen=(set oid:git)  ~
  |-
  ?~  pending  `seen
  ?:  (~(has in seen) i.pending)
    $(pending t.pending)
  =/  parents=(unit (list oid:git))  (commit-parents objects i.pending)
  ?~  parents  ~
  %=  $
    pending  (weld t.pending u.parents)
    seen  (~(put in seen) i.pending)
  ==
::
::  the nearest ancestor of .base that is also an ancestor of .head,
::  found breadth-first through .base's parents
::
++  merge-base
  |=  [objects=(map oid:git object:git) head=oid:git base=oid:git]
  ^-  (unit oid:git)
  =/  ancestors=(unit (set oid:git))  (commit-ancestors objects head)
  ?~  ancestors  ~
  =/  pending=(list oid:git)  ~[base]
  =/  seen=(set oid:git)  ~
  |-
  ?~  pending  ~
  ?:  (~(has in seen) i.pending)
    $(pending t.pending)
  ?:  (~(has in u.ancestors) i.pending)
    `i.pending
  =/  parents=(unit (list oid:git))  (commit-parents objects i.pending)
  ?~  parents  ~
  %=  $
    pending  (weld t.pending u.parents)
    seen  (~(put in seen) i.pending)
  ==
::
::  .head is the staged source head; .base is the destination tip it was
::  pushed against.  the destination tip is the merge's first parent.
::
++  materialize
  |=  $:  objects=(map oid:git object:git)
          head=oid:git
          base=oid:git
          author=@p
          now=@da
          message=@t
      ==
  ^-  outcome
  =/  head-ancestors=(unit (set oid:git))  (commit-ancestors objects head)
  ?~  head-ancestors
    [%conflict 'candidate head is not a complete commit graph']
  ?:  (~(has in u.head-ancestors) base)
    [%ready head objects]
  =/  base-ancestors=(unit (set oid:git))  (commit-ancestors objects base)
  ?~  base-ancestors
    [%conflict 'destination tip is not a complete commit graph']
  ?:  (~(has in u.base-ancestors) head)
    [%ready base objects]
  =/  common=(unit oid:git)  (merge-base objects head base)
  ?~  common
    [%conflict 'source and destination share no common ancestor']
  =/  merged=(unit [commit=oid:git objects=(map oid:git object:git)])
    (merge-commit:git-tree objects u.common base head author now message)
  ?~  merged
    [%conflict 'source has conflicting file changes with the destination']
  [%ready commit.u.merged objects.u.merged]
--
