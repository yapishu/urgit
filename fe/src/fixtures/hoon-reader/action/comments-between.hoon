|%
++  on-poke
  |=  act=[tag=@tas ~]
  |^
  (handle-action act)
  ++  handle-action
    |=  act=[tag=@tas ~]
    |^
    ::  the dispatch
    ::
    ?-  tag.act
      ::  a ref
      %set-ref  set-ref
      ::
      %other  wrong
    ==
    ::
    ++  set-ref
      0
    ++  wrong
      1
    --
  --
--
