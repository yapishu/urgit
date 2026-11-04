::  Parent native acceptance: execute production policy and ownership transitions.
/+  ci-input-test
:-  %say
|=  *
:-  %noun
=/  cases  vectors:ci-input-test
=/  failed  (skim cases |=([name=@t ok=?] !ok))
~&  cases
~&  [%passed (sub (lent cases) (lent failed)) %of (lent cases)]
=(~ failed)
