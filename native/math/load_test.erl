#!/usr/bin/env escript
%%! -noshell

try_loads() ->
    Paths = [
        "D:/projects/elixir/hxler/native/math/bin/cpp/Entry.dll",
        "D:\\projects\\elixir\\hxler\\native\\math\\bin\\cpp\\Entry.dll",
        "D:/projects/elixir/hxler/native/math/bin/cpp/Entry"
    ],
    lists:foreach(
        fun(P) ->
            R = erlang:load_nif(P, 0),
            S = case R of
                ok -> "OK";
                {error, {load_failed, M}} when is_list(M) -> "FAIL(" ++ unicode:characters_to_list(M) ++ ")";
                {error, R2} -> io_lib:format("~p", [R2])
            end,
            io:format("~ts => ~ts~n", [P, S])
        end,
        Paths).

main(_) ->
    try_loads().
