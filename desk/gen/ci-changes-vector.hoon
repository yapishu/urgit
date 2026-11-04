::  ci-changes-vector: the changed paths a push or a pull request is
::  filtered on (Delivery 1C), from a small store of real Git objects —
::  blobs, trees, commits and an annotated tag in canonical bytes, each id
::  SHA-1 over the loose-object form.  Checked here:
::    - two-dot for a push to an existing ref: a modified, an added and a
::      deleted path; a rename is both paths; a mode change; a file that
::      becomes a directory; a change made and reverted inside the push is
::      no change; an unchanged subtree is never read, even when absent;
::    - a new ref: from the first parent of the deepest commit it brought
::      (other branches and tags, an annotated tag peeled, a tree tip
::      standing for no commit), the empty tree for a root, nothing for a
::      tip already reachable;
::    - a pull request, three-dot: the head's changes since the merge
::      base, never the target's; the union over a criss-cross's two best
::      bases; the empty tree for unrelated histories;
::    - unavailable evidence, with the reason: a missing commit or tree, a
::      malformed one, an object of the wrong kind, a missing tip, and the
::      10,000-path bound at its edge.
::  Every case names the verdict it expects; prints `passed=N of=M` and
::  ends in a loobean.
::
/-  git
/+  ci-changes, git-codec, git-clay
:-  %say
|=  *
:-  %noun
=/  has-text
  |=  [text=@t part=@t]
  ^-  ?
  ?=(^ (find (trip part) (trip text)))
=/  put
  |=  [s=(map oid:git object:git) kind=object-kind:git data=octs]
  ^-  [oid:git (map oid:git object:git)]
  =/  id=oid:git  (object-oid:git-codec kind data)
  [id (~(put by s) id [kind data])]
=/  tree-data
  |=  entries=(list [mode=@t name=@t oid=oid:git])
  ^-  octs
  %-  join-all:git-codec
  (turn entries |=([m=@t n=@t o=oid:git] (tree-record:git-clay m n o)))
=/  commit-data
  |=  [tree=oid:git parents=(list oid:git) message=@t]
  ^-  octs
  %-  text:git-codec
  %+  rap  3
  :~  'tree '  (oid-text:git-codec tree)  '\0a'
      (rap 3 (turn parents |=(p=oid:git (rap 3 ~['parent ' (oid-text:git-codec p) '\0a']))))
      'author A <a@example.com> 1700000000 +0000\0a'
      'committer A <a@example.com> 1700000000 +0000\0a\0a'
      message  '\0a'
  ==
=|  s=(map oid:git object:git)
::  blobs
::
=^  b-a  s  (put s %blob (text:git-codec 'hello\0a'))
=^  b-b  s  (put s %blob (text:git-codec 'hello world\0a'))
=^  b-j1  s  (put s %blob (text:git-codec 'one\0a'))
=^  b-j2  s  (put s %blob (text:git-codec 'two\0a'))
=^  b-g  s  (put s %blob (text:git-codec 'guide\0a'))
=^  b-s  s  (put s %blob (text:git-codec 'run\0a'))
=^  b-l  s  (put s %blob (text:git-codec 'license\0a'))
::  trees
::
=^  src1  s  (put s %tree (tree-data ~[['100644' 'app.js' b-j1] ['100644' 'run.sh' b-s]]))
=^  src2  s  (put s %tree (tree-data ~[['100644' 'app.js' b-j2] ['100644' 'run.sh' b-s]]))
=^  src3  s  (put s %tree (tree-data ~[['100644' 'app.js' b-j1] ['100755' 'run.sh' b-s]]))
=^  docs1  s  (put s %tree (tree-data ~[['100644' 'guide.md' b-g]]))
=^  docs2  s  (put s %tree (tree-data ~[['100644' 'README.md' b-b] ['100644' 'guide.md' b-g]]))
=^  root0  s  (put s %tree (tree-data ~[['100644' 'README.md' b-a] ['40000' 'src' src1]]))
=^  root1  s  (put s %tree (tree-data ~[['100644' 'README.md' b-a] ['40000' 'src' src2]]))
=^  root2  s
  %^  put
    s
    %tree
  (tree-data ~[['100644' 'README.md' b-b] ['40000' 'docs' docs1] ['40000' 'src' src2]])
=^  root3  s  (put s %tree (tree-data ~[['40000' 'docs' docs1] ['40000' 'src' src2]]))
=^  root4  s  (put s %tree (tree-data ~[['40000' 'docs' docs2] ['40000' 'src' src2]]))
=^  root5  s  (put s %tree (tree-data ~[['100644' 'README.md' b-a] ['40000' 'src' src3]]))
=^  root6  s  (put s %tree (tree-data ~[['100644' 'README.md' b-a] ['100644' 'src' b-j1]]))
=^  root-m  s
  %^  put
    s
    %tree
  %-  tree-data
  ~[['100644' 'LICENSE' b-l] ['100644' 'README.md' b-a] ['40000' 'src' src1]]
::  0xdead and 0xbeef are trees no store holds
=^  root7  s  (put s %tree (tree-data ~[['100644' 'README.md' b-a] ['40000' 'vendor' 0xdead]]))
=^  root8  s  (put s %tree (tree-data ~[['100644' 'README.md' b-b] ['40000' 'vendor' 0xdead]]))
=^  root9  s  (put s %tree (tree-data ~[['100644' 'README.md' b-a] ['40000' 'vendor' 0xbeef]]))
=^  root-x1  s
  %^  put
    s
    %tree
  %-  tree-data
  ~[['100644' 'README.md' b-a] ['100644' 'a.txt' b-g] ['40000' 'src' src1]]
=^  root-y1  s
  %^  put
    s
    %tree
  %-  tree-data
  ~[['100644' 'README.md' b-a] ['100644' 'b.txt' b-g] ['40000' 'src' src1]]
=^  root-xm  s
  %^  put
    s
    %tree
  %-  tree-data
  ~[['100644' 'README.md' b-a] ['100644' 'a.txt' b-g] ['100644' 'b.txt' b-g] ['40000' 'src' src1]]
=^  root-xh  s
  %^  put
    s
    %tree
  %-  tree-data
  ~[['100644' 'README.md' b-a] ['100644' 'a.txt' b-g] ['100644' 'b.txt' b-g] ['100644' 'h.txt' b-g] ['40000' 'src' src1]]
=^  root-u  s  (put s %tree (tree-data ~[['100644' 'other.txt' b-g]]))
=^  bad-tree  s  (put s %tree (text:git-codec 'xx'))
::  commits: c0 the root, c1 edits src/app.js, c2 edits README.md and adds
::  docs/guide.md, c3 deletes README.md, c4 moves it to docs/, c5 changes
::  a mode, c6 makes src a file, c-r reverts c1's edit; m1 is the target
::  branch moved on from c0; x1, y1, xm, ym a criss-cross and xh a head
::  on it; u0 an unrelated root
::
=^  c0  s  (put s %commit (commit-data root0 ~ 'root'))
=^  c1  s  (put s %commit (commit-data root1 ~[c0] 'edit app'))
=^  c2  s  (put s %commit (commit-data root2 ~[c1] 'edit readme, add guide'))
=^  c3  s  (put s %commit (commit-data root3 ~[c2] 'delete readme'))
=^  c4  s  (put s %commit (commit-data root4 ~[c2] 'move readme'))
=^  c5  s  (put s %commit (commit-data root5 ~[c0] 'mode'))
=^  c6  s  (put s %commit (commit-data root6 ~[c0] 'src is a file'))
=^  c-r  s  (put s %commit (commit-data root0 ~[c1] 'revert'))
=^  c7  s  (put s %commit (commit-data root7 ~ 'vendored'))
=^  c8  s  (put s %commit (commit-data root8 ~[c7] 'readme beside vendored'))
=^  c9  s  (put s %commit (commit-data root9 ~[c7] 'vendored changed'))
=^  c-bad-tree  s  (put s %commit (commit-data bad-tree ~[c0] 'bad tree'))
=^  m1  s  (put s %commit (commit-data root-m ~[c0] 'license on main'))
=^  x1  s  (put s %commit (commit-data root-x1 ~[c0] 'a'))
=^  y1  s  (put s %commit (commit-data root-y1 ~[c0] 'b'))
=^  xm  s  (put s %commit (commit-data root-xm ~[x1 y1] 'merge b into a'))
=^  ym  s  (put s %commit (commit-data root-xm ~[y1 x1] 'merge a into b'))
=^  xh  s  (put s %commit (commit-data root-xh ~[xm] 'h'))
=^  u0  s  (put s %commit (commit-data root-u ~ 'unrelated'))
=^  bad-commit  s  (put s %commit (text:git-codec 'not a commit'))
=^  tag-v1  s
  %^  put  s  %tag
  %-  text:git-codec
  %+  rap  3
  :~  'object '  (oid-text:git-codec c1)  '\0atype commit\0atag v1\0a'
      'tagger A <a@example.com> 1700000000 +0000\0a\0arelease\0a'
  ==
::  a flat tree of .n paths, every one the same blob
::
=/  many
  |=  n=@ud
  ^-  octs
  %-  join-all:git-codec
  %+  turn  (gulf 1 n)
  |=  i=@ud
  (tree-record:git-clay '100644' (rap 3 ~['f' (crip (a-co:co i))]) b-a)
=^  big-at  s  (put s %tree (many 10.000))
=^  big-over  s  (put s %tree (many 10.001))
::
=/  paths
  |=  r=change-set:ci-changes
  ^-  (unit (list @t))
  ?:(?=(%| -.r) ~ `p.r)
=/  merge-base-list
  |=  r=(each (list oid:git) @t)
  ^-  (unit (list oid:git))
  ?:(?=(%| -.r) ~ `p.r)
=/  criss-cross=(unit (list oid:git))  (merge-base-list (merge-bases:ci-changes s xh ym))
=/  refused
  |=  [r=change-set:ci-changes part=@t]
  ^-  ?
  ?.  ?=(%| -.r)  %.n
  (has-text p.r part)
=/  push
  |=([old=(unit oid:git) new=oid:git others=(list oid:git)] (push-changes:ci-changes s old new others))
=/  pull  |=([head=oid:git target=oid:git] (pull-changes:ci-changes s head target))
=/  big-at-diff=change-set:ci-changes  (tree-diff:ci-changes s ~ `big-at)
::
=/  two-dot=(list [name=@t expect=? got=?])
  :~  ['a modified file is its path' %.y =(`~['src/app.js'] (paths (push `c0 c1 ~)))]
      ['a modified and an added file, in byte order' %.y =(`~['README.md' 'docs/guide.md'] (paths (push `c1 c2 ~)))]
      ['a deleted file is its path' %.y =(`~['README.md'] (paths (push `c2 c3 ~)))]
      ['a rename is a deletion and an addition: both paths' %.y =(`~['README.md' 'docs/README.md'] (paths (push `c2 c4 ~)))]
      ['a mode change is a change' %.y =(`~['src/run.sh'] (paths (push `c0 c5 ~)))]
      ['a file that becomes a directory: the file and every path under it' %.y =(`~['src' 'src/app.js' 'src/run.sh'] (paths (push `c0 c6 ~)))]
      ['several commits are one tree comparison: tip to tip' %.y =(`~['README.md' 'docs/guide.md' 'src/app.js'] (paths (push `c0 c2 ~)))]
      ['a change made and reverted inside the push is no change' %.y =(`~ (paths (push `c0 c-r ~)))]
      ['an unchanged subtree is never read, even when the store lacks it' %.y =(`~['README.md'] (paths (push `c7 c8 ~)))]
      ['a changed subtree the store lacks is unavailable, named' %.y (refused (push `c7 c9 ~) 'tree 000000000000000000000000000000000000dead is missing from the store')]
      ['a missing commit is unavailable' %.y (refused (push `c0 0xfeed ~) 'is missing from the store')]
      ['a malformed commit is unavailable' %.y (refused (push `c0 bad-commit ~) 'is malformed')]
      ['a malformed tree is unavailable' %.y (refused (push `c0 c-bad-tree ~) 'is malformed')]
      ['a blob is not a commit' %.y (refused (push `c0 b-a ~) 'is not a commit')]
  ==
=/  new-ref=(list [name=@t expect=? got=?])
  :~  ['a new ref from the first parent of the deepest commit it brought' %.y =(`~['README.md' 'docs/guide.md' 'src/app.js'] (paths (push ~ c2 ~[c0])))]
      ['an older branch tip nearer the new ref bounds it' %.y =(`~['README.md' 'docs/guide.md'] (paths (push ~ c2 ~[c1])))]
      ['several commits deep, against the nearest reachable one' %.y =(`~['README.md' 'docs/guide.md'] (paths (push ~ c3 ~[c1])))]
      ['an annotated tag is peeled to the commit it names' %.y =(`~['README.md' 'docs/guide.md'] (paths (push ~ c2 ~[tag-v1])))]
      ['a root the new ref brought: from the empty tree' %.y =(`~['README.md' 'docs/guide.md' 'src/app.js' 'src/run.sh'] (paths (push ~ c2 ~)))]
      ['a tree tip stands for no commit' %.y =(`~['README.md' 'docs/guide.md' 'src/app.js' 'src/run.sh'] (paths (push ~ c2 ~[root0])))]
      ['a new ref at a reachable commit brought nothing' %.y =(`~ (paths (push ~ c2 ~[c2])))]
      ['a missing tip makes the new ref\'s commits unknown' %.y (refused (push ~ c2 ~[0xfeed]) 'cannot be told apart')]
  ==
=/  three-dot=(list [name=@t expect=? got=?])
  :~  ['the merge base of a linear head is the target' %.y =(`~[c1] (merge-base-list (merge-bases:ci-changes s c2 c1)))]
      ['the merge base of a moved target is the fork point' %.y =(`~[c0] (merge-base-list (merge-bases:ci-changes s c2 m1)))]
      ['a head onto its target: its own changes' %.y =(`~['README.md' 'docs/guide.md'] (paths (pull c2 c1)))]
      ['the target moved on: the head\'s changes since the base, never the target\'s' %.y =(`~['README.md' 'docs/guide.md' 'src/app.js'] (paths (pull c2 m1)))]
      ['a criss-cross has two best bases' %.y ?~(criss-cross %.n =((silt u.criss-cross) (silt ~[x1 y1])))]
      ['and its paths are the union over both' %.y =(`~['a.txt' 'b.txt' 'h.txt'] (paths (pull xh ym)))]
      ['unrelated histories share no base' %.y =(`~ (merge-base-list (merge-bases:ci-changes s u0 c2)))]
      ['and compare from the empty tree' %.y =(`~['other.txt'] (paths (pull u0 c2)))]
      ['a missing head is unavailable' %.y (refused (pull 0xfeed c1) 'is missing from the store')]
  ==
=/  bounds=(list [name=@t expect=? got=?])
  :~  ['10,000 changed paths are evidence' %.y &(?=(%& -.big-at-diff) =(10.000 (lent p.big-at-diff)))]
      ['10,001 are unavailable, the bound named' %.y (refused (tree-diff:ci-changes s ~ `big-over) 'more than 10000 paths changed')]
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld two-dot new-ref three-dot bounds)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
