|%
++  on-poke
  |=  act=[tag=@tas ~]
  |^
  (handle-action act)
  ++  handle-action
    |=  act=[tag=@tas ~]
    |^
    ?-  tag.act
      %set-ref  set-ref
      %other  wrong
    ==
    ++  set-ref
      0
    ++  wrong
      1
    --
  --
--
