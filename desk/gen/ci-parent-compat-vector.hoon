::  Parent counterexamples for the two inherited compatibility findings.
::  Expectations follow actions/runner EvaluationResult and Contains,
::  using OrdinalIgnoreCase and IndexOf respectively; not this evaluator.
/-  ci
/+  ci-expr
:-  %say
|=  *
:-  %noun
=/  str  |=(t=@t `expr:ci`[%str t])
=/  is-true
  |=  e=expr:ci
  ^-  ?
  =(&+[%bool %.y] (eval:ci-expr e empty-scope:ci-expr))
=/  contains
  |=  [a=@t b=@t]
  ^-  ?
  (is-true [%call 'contains' ~[(str a) (str b)]])
=/  cases=(list [name=@t expect=? got=?])
  :~  ['ASCII order: a sorts before underscore ignoring case' %.y (is-true [%cmp %lt (str 'a') (str '_')])]
      ['same non-ASCII prefix: Éa sorts before É_ ignoring case' %.y (is-true [%cmp %lt (str 'Éa') (str 'É_')])]
      ['a nonempty string contains the empty string' %.y (contains 'abc' '')]
      ['the empty string contains the empty string' %.y (contains '' '')]
      ['a string with a related non-ASCII letter contains empty text' %.y (contains 'ſ' '')]
      ['positive control: a sorts before B ignoring case' %.y (is-true [%cmp %lt (str 'a') (str 'B')])]
      ['positive control: ordinary nonempty substring' %.y (contains 'abc' 'B')]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
