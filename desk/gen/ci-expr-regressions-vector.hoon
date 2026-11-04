::  ci-expr-regressions-vector: the parent-curated semantic-regression
::  intents of the 1B comparison (.scratch reference semantic-regressions)
::  that the selected engine had no explicit case for.  Every expectation
::  is GitHub's (binary64 with IEEE-754 round-half-to-even, loose
::  comparison, text compared without case), never read from the engine.
::
::    correction-02: the original vector called the boolean helper
::    +compare, which could not say "unsupported"; natively it returned
::    13/14, failing "non-ASCII text without case is equal, never a silent
::    false" (École against éCOLE: a silent false).  that capture and the
::    original source are kept (.scratch/workflow/out/correction-02/
::    evidence).  the numeric intentions below are unchanged, case for
::    case; the four comparison intentions now run through the public
::    evaluator (+eval), and the non-ASCII one takes its permitted answer:
::    an explicit error naming both texts and the limit — still never a
::    silent false.  its positive companions: identical non-ASCII texts,
::    and texts equal up to ASCII case, are equal; a decidable difference
::    is false.
::
::  Prints `passed=N of=M` and ends in a loobean.
::
/-  ci
/+  ci-expr
:-  %say
|=  *
:-  %noun
=/  num  to-number:ci-expr
=/  eq
  |=  [a=@t b=@t]
  ^-  ?
  (compare-numbers:ci-expr %eq (num a) (num b))
=/  str  |=(t=@t `expr:ci`[%str t])
=/  cmp  |=([l=expr:ci r=expr:ci] `expr:ci`[%cmp %eq l r])
=/  ev
  |=  e=expr:ci
  ^-  (each val:ci-expr @t)
  (eval:ci-expr e empty-scope:ci-expr)
=/  has-text
  |=  [text=@t part=@t]
  ^-  ?
  ?=(^ (find (trip part) (trip text)))
=/  french=(each val:ci-expr @t)  (ev (cmp (str 'École') (str 'éCOLE')))
=/  cases=(list [name=@t expect=? got=?])
  :~  ['2^53 + 1 reads as 2^53 (halfway, to even)' %.y (eq '9007199254740993' '9007199254740992')]
      ['2^53 + 3 reads as 2^53 + 4 (halfway, to even)' %.y (eq '9007199254740995' '9007199254740996')]
      ['2^53 + 1 is not 2^53 + 2' %.n (eq '9007199254740993' '9007199254740994')]
      ['two decimals of one double are one number' %.y (eq '0.1' '0.1000000000000000055511151231257827')]
      ['the largest finite double reads finite' %.y =(.~1.7976931348623157e308 (num '1.7976931348623157e308'))]
      ['past it reads as Infinity' %.y =(inf-rd:ci-expr (num '1e309'))]
      ['the smallest subnormal reads nonzero' %.y !(zero:ci-expr (num '5e-324'))]
      ['below half of it reads as zero' %.y (zero:ci-expr (num '2e-324'))]
      ['negative zero equals zero' %.y (eq '-0' '0')]
      ['2^53 + 1 is written as G15 writes 2^53' %.y =('9.00719925474099E+15' (number-text:ci-expr (num '9007199254740993')))]
      ['numeric texts compare as texts' %.y =(&+[%bool %.n] (ev (cmp (str '1.0') (str '1'))))]
      ['a text against a number compares as numbers' %.y =(&+[%bool %.y] (ev (cmp (str '1.0') [%num (num '1')])))]
      ['NaN equals nothing, itself included' %.y =(&+[%bool %.n] (ev (cmp [%num nan-rd:ci-expr] [%num nan-rd:ci-expr])))]
      ['non-ASCII text without case is never a silent false' %.y !=(&+[%bool %.n] french)]
      :+  'non-ASCII text without case is an explicit error naming both texts and the limit'  %.y
      ?&  ?=(%| -.french)
          (has-text p.french 'not supported for non-ASCII letters')
          (has-text p.french 'École')
          (has-text p.french 'éCOLE')
          (has-text p.french 'ASCII letters only')
      ==
      ['identical non-ASCII texts are equal' %.y =(&+[%bool %.y] (ev (cmp (str 'École') (str 'École'))))]
      ['non-ASCII texts equal up to ASCII case are equal' %.y =(&+[%bool %.y] (ev (cmp (str 'École') (str 'ÉCOLE'))))]
      ['a difference no case mapping can make equal is false' %.y =(&+[%bool %.n] (ev (cmp (str 'café') (str 'cafe'))))]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
