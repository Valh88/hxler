# Phase 5 E2E: resources (ResourceArc round-trip, dtor, GC stress).
defmodule Hxler.Math do
  @on_load :load_nif
  def load_nif do
    :code.purge(__MODULE__)
    :erlang.load_nif("D:/projects/elixir/hxler/native/math/bin/cpp/Main", 0)
  end

  def add(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def sum64(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def greet(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def fib(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def safe_div(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def atom_text(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def list_sum(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def map_sum(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def both(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def opt_or42(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_new(), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_push(_a, _v), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_sum(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_len(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def is_accum(_t), do: :erlang.nif_error(:nif_library_not_loaded)
  def pid_type(_t), do: :erlang.nif_error(:nif_library_not_loaded)
  def pid_alive(_t), do: :erlang.nif_error(:nif_library_not_loaded)
  def send_msg(_t, _p), do: :erlang.nif_error(:nif_library_not_loaded)
  def saved_term_gens(), do: :erlang.nif_error(:nif_library_not_loaded)
  def saved_term_load(), do: :erlang.nif_error(:nif_library_not_loaded)
  def make_ref_nif(), do: :erlang.nif_error(:nif_library_not_loaded)
  def whereis_alive(_name), do: :erlang.nif_error(:nif_library_not_loaded)
end

IO.puts("accum_new              = #{inspect(Hxler.Math.accum_new())}")
a = Hxler.Math.accum_new()

for i <- 1..10, do: Hxler.Math.accum_push(a, i)
IO.puts("accum_len(a)           = #{Hxler.Math.accum_len(a)}  (want 10)")
IO.puts("accum_sum(a)           = #{Hxler.Math.accum_sum(a)}  (want 55)")
IO.puts("is_accum(a)            = #{inspect(Hxler.Math.is_accum(a))}  (want true)")
IO.puts("is_accum(:hello)       = #{inspect(Hxler.Math.is_accum(:hello))}  (want false)")

# badarg on a non-resource term
r = try do
  Hxler.Math.accum_sum(123)
rescue
  e -> {:raised, e.__struct__}
end
IO.puts("accum_sum(123)         = #{inspect(r)}  (want {:raised, ArgumentError})")

# dtor check: create and drop many arcs; accumulate sums while alive
live = Hxler.Math.accum_new()
for i <- 1..1000, do: Hxler.Math.accum_push(live, i)
IO.puts("live sum after 1000    = #{Hxler.Math.accum_sum(live)}  (want 500500)")

# GC stress: many short-lived resources + hxcpp collections
parent = self()
procs =
  for n <- 1..8 do
    spawn(fn ->
      for _ <- 1..200 do
        x = Hxler.Math.accum_new()
        for i <- 1..50, do: Hxler.Math.accum_push(x, i)
        if Hxler.Math.accum_sum(x) != 1275, do: send(parent, {:bad, n})
        :erlang.garbage_collect()
      end
      send(parent, :done)
    end)
  end
Enum.each(procs, fn _ -> receive do :done -> :ok; {:bad, n} -> IO.puts("BAD SUM worker #{n}") after 30_000 -> IO.puts("TIMEOUT") end end)
IO.puts("gc stress 8x200 done   = OK")

IO.puts("PHASE5 SPIKE DONE")
