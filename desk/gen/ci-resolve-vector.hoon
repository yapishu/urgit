::  Parent-owned native execution of production resolver transition vectors.
/+  ci-resolve-test
:-  %say
|=  *
:-  %noun
=/  cases  vectors:ci-resolve-test
=/  failed  (skim cases |=([name=@t ok=?] !ok))
~&  cases
~&  [%passed (sub (lent cases) (lent failed)) %of (lent cases)]
=(~ failed)
