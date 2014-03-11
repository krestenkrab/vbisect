vbisect
=======

Vbisect is a variable-sized binary ordered dictionary implemented
in erlang. All keys and values in the dictionary have been converted
to binaries, then encoded in a single large binary as a breadth-first
traversal of the tree's leaves represented as an array with
variable-sized elements.

### Data representation

An encoded vbisect dictionary can contain 2^32 entries, each
of which has a key of not more than 2^16 bytes and a value of
not more than 2^32 bytes, and the entire dictionary must fit
in your available RAM. In general, they have been optimized
for a 32-bit architecture but should work well on 64-bit
environments.

Vbisect binaries are defined with the following fields in
order (the key and value pairs are repeated as many times
as are defined by the number of entries):

```
Id:                 <<"vbis">>
Number of entries:  <<Count:32/unsigned>>

Key Size:           <<Key_Size:16>>
Key:                <<Key/binary>>

Value Size:         <<Value_Size:32>>
Value:              <<Value/binary>>

```

### Interface

The main usage is to convert orddicts and gb_trees to vbisects
and subsequently to access the data values using find and fold.
Ensure that all keys and values are binaries in any source
orddict or gb_tree:

```
from_orddict(Orddict) -> Vbisect.
to_orddict(Vbisect)   -> Orddict.

from_gb_tree(Tree)    -> Vbisect.
to_gb_tree(Vbisect)   -> Tree.

find(Key, Vbisect)    -> {ok, Value} | error.
find_geq(Key, Vbisect) -> {ok, Key, Value} | none.

foldl(fun(Key, Value, Accum) -> Accum1), Accum0, Vbisect0) -> Vbisect1.
foldr(fun(Key, Value, Accum) -> Accum1), Accum0, Vbisect0) -> Vbisect1.

merge(Compare_Fn, Orddict1, Orddict2) -> Orddict3.

```

### Quick start

To play around with the code after cloning from github:

```
cd vbisect
make
erl
1> cd(ebin).

2> vbisect:module_info().
     ... info about exports ...

3> Props = [{<<"name">>, <<"joe">>}, {<<"age">>, <<"28">>}, {<<"sex">>, <<"M">>}].
[{<<"name">>,<<"joe">>},
 {<<"age">>,<<"28">>},
 {<<"sex">>,<<"M">>}]

4> orddict:from_list(v(3)).
[{<<"age">>,<<"28">>},
 {<<"name">>,<<"joe">>},
 {<<"sex">>,<<"M">>}]

5> vbisect:from_orddict(v(4)).
<<118,98,105,115,0,0,0,3,0,4,110,97,109,101,0,0,0,15,0,3,
  97,103,101,0,0,0,0,0,0,...>>

```

### Building with your own application

To include this code in your own erlang application, add the
following to your *.app.src* file:

```
{application, myapp,
 [
  {id, ...},
   ...,
  {included_applications, [vbisect]
]}
```

Then add this to your erlang.mk Makefile:

```
DEPS = vbisect
dep_vbisect = https://github.com/krestenkrab/vbisect.git 0.1.0
```

or this to your rebar.config:

```
  {vbisect, "0.1.0", {git, "git@github.com:krestenkrab/vbisect.git", {tag, "0.1.0"}}}
```


### Contributors

Based on original work at https://github.com/knutin/bisect

- Kresten Krab Thorup @krestenkrab
- Jay Nelson @duomark
