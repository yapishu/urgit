|%
++  on-poke
  |=  act=[tag=@tas ~]
  |^
  (handle-action act)
  ++  handle-action
    |=  act=[tag=@tas ~]
    |^
    ?-  tag.act
      %set-ref  delete
      %del  delete
    ==
    ++  set-ref
      0
    ++  del
      1
    ++  delete
      2
    --
  --
--
