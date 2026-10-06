::  Regression vectors for occurrence-aware line ancestry.
::
/-  git
/+  git-blame
:-  %say
|=  *
:-  %noun
=/  newest=octs  [8 0xa63.0a61.0a62.0a61]
=/  parent=octs  [6 0xa63.0a61.0a61]
=/  root=octs  [4 0xa63.0a61]
=/  initial=(list slot:git-blame)  (seed:git-blame newest)
=/  one=(list slot:git-blame)  (step:git-blame initial parent 1)
=/  two=(list slot:git-blame)  (step:git-blame one root 2)
=/  sources=(list @ud)  (turn two |=(item=slot:git-blame source.item))
:-  =(5 (lent initial))
:-  =(~[2 0 1 2 2] sources)
:-  (any-active:git-blame two)
:-  !(any-active:git-blame (deactivate:git-blame two))
~
