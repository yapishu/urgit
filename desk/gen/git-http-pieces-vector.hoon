::  A large response body is given as bounded pieces that rejoin to it.
::
/+  *git-http
:-  %say
|=  *
:-  %noun
=/  rejoin
  |=  pieces=(list octs)
  ^-  octs
  :-  (roll pieces |=([piece=octs total=@ud] (add p.piece total)))
  (can 3 pieces)
=/  body=octs  [10 0x9.0807.0605.0403.0201]
=/  trailing=octs  [5 0x10.2030]
=/  three=(list octs)  (body-pieces body 4)
=/  whole=(list octs)  (body-pieces body 10)
=/  ones=(list octs)  (body-pieces body 1)
=/  zeros=(list octs)  (body-pieces trailing 2)
=/  small=(list card:agent:gall)
  (give-http 'r' 200 ~ `[3 0x3.0201])
=/  empty=(list card:agent:gall)  (give-http 'r' 204 ~ ~)
:~  =(3 (lent three))
    =(~[4 4 2] (turn three |=(piece=octs p.piece)))
    =(body (rejoin three))
    =(~[body] whole)
    =(10 (lent ones))
    =(body (rejoin ones))
    =(~[2 2 1] (turn zeros |=(piece=octs p.piece)))
    =(trailing (rejoin zeros))
    =(~ (body-pieces [0 0] 4))
    =(3 (lent small))
    =(3 (lent empty))
    =(67.108.864 body-piece)
    (lth (mul 8 body-piece) (bex 32))
==
