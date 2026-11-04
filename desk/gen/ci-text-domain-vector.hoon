::  Parent public-evaluator domain regression: collections are not text.
/-  ci
/+  ci-expr
:-  %say
|=  *
:-  %noun
=/  js  |=(text=@t `expr:ci`[%call 'fromjson' ~[[%str text]]])
=/  is
  |=  [fn=@t a=expr:ci b=expr:ci want=?]
  ^-  ?
  =(&+[%bool want] (eval:ci-expr [%call fn ~[a b]] empty-scope:ci-expr))
=/  cases=(list [name=@t expect=? got=?])
  :~  ['contains does not stringify a collection needle []' %.y (is 'contains' [%str 'x'] (js '[]') %.n)]
      ['contains does not stringify a collection needle {}' %.y (is 'contains' [%str 'x'] (js '{}') %.n)]
      ['startswith does not stringify a collection needle []' %.y (is 'startswith' [%str 'x'] (js '[]') %.n)]
      ['startswith does not stringify a collection needle {}' %.y (is 'startswith' [%str 'x'] (js '{}') %.n)]
      ['endswith does not stringify a collection needle []' %.y (is 'endswith' [%str 'x'] (js '[]') %.n)]
      ['endswith does not stringify a collection needle {}' %.y (is 'endswith' [%str 'x'] (js '{}') %.n)]
      ['startswith does not stringify a collection haystack []' %.y (is 'startswith' (js '[]') [%str ''] %.n)]
      ['startswith does not stringify a collection haystack {}' %.y (is 'startswith' (js '{}') [%str ''] %.n)]
      ['endswith does not stringify a collection haystack []' %.y (is 'endswith' (js '[]') [%str ''] %.n)]
      ['endswith does not stringify a collection haystack {}' %.y (is 'endswith' (js '{}') [%str ''] %.n)]
      ['array membership remains true for an empty element' %.y (is 'contains' (js '[""]') [%str ''] %.y)]
      ['array membership is not empty substring search' %.y (is 'contains' (js '["abc"]') [%str ''] %.n)]
      ['object haystack remains false' %.y (is 'contains' (js '{}') [%str ''] %.n)]
      ['a string contains empty text' %.y (is 'contains' [%str 'x'] [%str ''] %.y)]
      ['a string starts with empty text' %.y (is 'startswith' [%str 'x'] [%str ''] %.y)]
      ['a string ends with empty text' %.y (is 'endswith' [%str 'x'] [%str ''] %.y)]
      ['null remains primitive empty text' %.y (is 'contains' [%bool %.n] [%null ~] %.y)]
      ['ASCII matching remains insensitive' %.y (is 'contains' [%str 'x'] [%str 'X'] %.y)]
      ['contains rejects a Array needle even when its type name matches the text' %.y (is 'contains' [%str 'Array'] (js '[]') %.n)]
      ['contains rejects a Object needle even when its type name matches the text' %.y (is 'contains' [%str 'Object'] (js '{}') %.n)]
      ['startswith rejects a Array needle even when its type name matches the text' %.y (is 'startswith' [%str 'Array'] (js '[]') %.n)]
      ['startswith rejects a Object needle even when its type name matches the text' %.y (is 'startswith' [%str 'Object'] (js '{}') %.n)]
      ['endswith rejects a Array needle even when its type name matches the text' %.y (is 'endswith' [%str 'Array'] (js '[]') %.n)]
      ['endswith rejects a Object needle even when its type name matches the text' %.y (is 'endswith' [%str 'Object'] (js '{}') %.n)]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
~&  [%failed failed]
~&  (crip "passed={<(sub (lent cases) (lent failed))>} of={<(lent cases)>}")
?=(~ failed)
