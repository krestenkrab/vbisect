

-module(vbisect).

-export([from_orddict/1, from_gb_tree/1, to_gb_tree/1, find/2, find_geq/2, foldl/3, foldr/3, to_orddict/1, merge/3]).

-define(MAGIC, "vbis").
-type key() :: binary().
-type value() :: binary().
-type bindict() :: binary().

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-spec from_gb_tree(gb_tree()) -> bindict().
from_gb_tree({Count,Node}) when Count =< 16#ffffffff ->
    {_BinSize,IOList} = encode_gb_node(Node),
    erlang:iolist_to_binary([ <<?MAGIC,  Count:32/unsigned >> | IOList ]).

encode_gb_node({Key, Value, Smaller, Bigger}) when is_binary(Key), is_binary(Value) ->
    {BinSizeSmaller, IOSmaller} = encode_gb_node(Smaller),
    {BinSizeBigger, IOBigger} = encode_gb_node(Bigger),

    KeySize = byte_size(Key),
    ValueSize = byte_size(Value),
    { 2 + KeySize
      + 4 + ValueSize
      + 4 + BinSizeSmaller
      + BinSizeBigger,

      [ << KeySize:16, Key/binary,
           BinSizeSmaller:32 >>, IOSmaller,
        << ValueSize:32, Value/binary >> | IOBigger ] };

encode_gb_node(_) ->
    { 0, [] }.

to_gb_tree(<<?MAGIC,  Count:32, Nodes/binary >>) ->
    { Count, to_gb_node(Nodes) }.

to_gb_node( <<>> ) ->
    nil;

to_gb_node( << KeySize:16, Key:KeySize/binary,
               BinSizeSmaller:32, Smaller:BinSizeSmaller/binary,
               ValueSize:32, Value:ValueSize/binary,
               Bigger/binary >> ) ->
    {Key, Value,
     to_gb_node(Smaller),
     to_gb_node(Bigger)}.

-spec find(Key::key(), Dict::bindict()) ->
                  { ok, value() } | error.
find(Key, <<?MAGIC, _:32, Binary/binary>>) ->
    find_node(byte_size(Key), Key, Binary).

find_node(KeySize, Key, <<HereKeySize:16, HereKey:HereKeySize/binary,
                          BinSizeSmaller:32, _:BinSizeSmaller/binary,
                          ValueSize:32, Value:ValueSize/binary,
                          _/binary>> = Bin) ->
    if
        Key < HereKey ->
            Skip = 6 + HereKeySize,
            << _:Skip/binary, Smaller:BinSizeSmaller/binary, _/binary>> = Bin,
            find_node(KeySize, Key, Smaller);
        HereKey < Key ->
            Skip = 10 + HereKeySize + BinSizeSmaller + ValueSize,
            << _:Skip/binary, Bigger/binary>> = Bin,
            find_node(KeySize, Key, Bigger);
        true ->
            {ok, Value}
    end;

find_node(_, _, <<>>) ->
    error.

to_orddict(BinDict) ->
    foldr(fun(Key,Value,Acc) ->
                  [{Key,Value}|Acc]
          end,
          [],
          BinDict).

merge(Fun, BinDict1, BinDict2) ->
    OD1 = to_orddict(BinDict1),
    OD2 = to_orddict(BinDict2),
    OD3 = orddict:merge(Fun, OD1, OD2),
    from_orddict(OD3).

%% @doc Find largest KV smaller than or equal to key.
%% This is good for an inner node where key is the smallest key
%% in the child node.

-spec find_geq(Key::binary(), Binary::binary()) ->
                      none | {ok, Key::key(), Value::value()}.

find_geq(Key, <<?MAGIC, _:32, Binary/binary>>) ->
    find_geq_node(byte_size(Key), Key, Binary, none).

find_geq_node(_, _, <<>>, Else) ->
    Else;

find_geq_node(KeySize, Key, <<HereKeySize:16, HereKey:HereKeySize/binary,
                              BinSizeSmaller:32, _:BinSizeSmaller/binary,
                              ValueSize:32, Value:ValueSize/binary,
                              _/binary>> = Bin, Else) ->
    if
        HereKey > Key ->
            if Else =:= none ->
                    Skip = 6 + HereKeySize,
                    << _:Skip/binary, Smaller:BinSizeSmaller/binary, _/binary>> = Bin,
                    find_geq_node(KeySize, Key, Smaller, Else);
               true ->
                    Else
            end;
        HereKey < Key ->
            Skip = 10 + HereKeySize + BinSizeSmaller + ValueSize,
            << _:Skip/binary, Bigger/binary>> = Bin,
            find_geq_node(KeySize, Key, Bigger, {ok, HereKey, Value});
        true ->
            {ok, HereKey, Value}
    end.

-spec foldl(fun((Key::key(), Value::value(), Acc::term()) -> term()), term(), bindict()) ->
                   term().
foldl(Fun, Acc, <<?MAGIC, _:32, Binary/binary>>) ->
    foldl_node(Fun, Acc, Binary).

foldl_node(_Fun, Acc, <<>>) ->
    Acc;

foldl_node(Fun, Acc, <<KeySize:16, Key:KeySize/binary,
                       BinSizeSmaller:32, Smaller:BinSizeSmaller/binary,
                       ValueSize:32, Value:ValueSize/binary,
                       Bigger/binary>>) ->
    Acc1 = foldl_node(Fun, Acc, Smaller),
    Acc2 = Fun(Key, Value, Acc1),
    foldl_node(Fun, Acc2, Bigger).


-spec foldr(fun((Key::key(), Value::value(), Acc::term()) -> term()), term(), bindict()) ->
                   term().
foldr(Fun, Acc, <<?MAGIC, _:32, Binary/binary>>) ->
    foldr_node(Fun, Acc, Binary).

foldr_node(_Fun, Acc, <<>>) ->
    Acc;

foldr_node(Fun, Acc, <<KeySize:16, Key:KeySize/binary,
                       BinSizeSmaller:32, Smaller:BinSizeSmaller/binary,
                       ValueSize:32, Value:ValueSize/binary,
                       Bigger/binary>>) ->
    Acc1 = foldr_node(Fun, Acc, Bigger),
    Acc2 = Fun(Key, Value, Acc1),
    foldr_node(Fun, Acc2, Smaller).


from_orddict(OrdDict) ->
    from_gb_tree(gb_trees:from_orddict(OrdDict)).

-ifdef(TEST).

speed_test_() ->
    {timeout, 600,
     fun() ->
             Start = 100000000000000,
             N = 100000,
             Keys = lists:seq(Start, Start+N),
             KeyValuePairs = lists:map(fun (I) -> {<<I:64/integer>>, <<255:8/integer>>} end,
                                       Keys),

             %% Will mostly be unique, if N is bigger than 10000
             ReadKeys = [<<(lists:nth(random:uniform(N), Keys)):64/integer>> || _ <- lists:seq(1, 1000)],
             B = from_orddict(KeyValuePairs),
             time_reads(B, N, ReadKeys)
     end}.


time_reads(B, Size, ReadKeys) ->
    Parent = self(),
    spawn(
      fun() ->
              Runs = 20,
              Timings =
                  lists:map(
                    fun (_) ->
                            StartTime = now(),
                            find_many(B, ReadKeys),
                            timer:now_diff(now(), StartTime)
                    end, lists:seq(1, Runs)),

              Rps = 1000000 / ((lists:sum(Timings) / length(Timings)) / 1000),
              error_logger:info_msg("Average over ~p runs, ~p keys in dict~n"
                                    "Average fetch ~p keys: ~p us, max: ~p us~n"
                                    "Average fetch 1 key: ~p us~n"
                                    "Theoretical sequential RPS: ~w~n",
                                    [Runs, Size, length(ReadKeys),
                                     lists:sum(Timings) / length(Timings),
                                     lists:max(Timings),
                                     (lists:sum(Timings) / length(Timings)) / length(ReadKeys),
                                     trunc(Rps)]),

              Parent ! done
      end),
    receive done -> ok after 1000 -> ok end.

-spec find_many(bindict(), [key()]) -> [value() | not_found].
find_many(B, Keys) ->
    lists:map(fun (K) -> find(K, B) end, Keys).

-endif.
