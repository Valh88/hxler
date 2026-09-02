# Phase 4 E2E: fully macro-generated NIF (Entry + MathNif via @:nif).
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

IO.puts("add(20, 22)            = #{inspect(Hxler.Math.add(20, 22))}  (want 42)")
IO.puts("sum64(2^40, 42)        = #{inspect(Hxler.Math.sum64(1_099_511_627_776, 42))}  (want 1099511627818)")
IO.puts("greet(\"hx\")            = #{inspect(Hxler.Math.greet("hx"))}  (want \"Hello, hx!\")")
IO.puts("fib(90)                = #{inspect(Hxler.Math.fib(90))}  (want 2880067194370816120, dirty_cpu)")
IO.puts("safe_div(84, 2)        = #{inspect(Hxler.Math.safe_div(84, 2))}  (want 42: NifResult<Term> -> term)")
IO.puts("safe_div(1, 0)         = #{inspect(Hxler.Math.safe_div(1, 0))}  (want {:error, :zero_division})")
IO.puts("atom_text(:hello)      = #{inspect(Hxler.Math.atom_text(:hello))}  (want \"hello\", raw fn)")
IO.puts("list_sum([1,2,3,4,5])  = #{inspect(Hxler.Math.list_sum([1, 2, 3, 4, 5]))}  (want 15)")
IO.puts("map_sum(%{\"a\"=>20,\"b\"=>22}) = #{inspect(Hxler.Math.map_sum(%{"a" => 20, "b" => 22}))}  (want 42)")
IO.puts("both(true, 21.0)       = #{inspect(Hxler.Math.both(true, 21.0))}  (want 42.0)")
IO.puts("opt_or42(nil)          = #{inspect(Hxler.Math.opt_or42(nil))}  (want 42)")
IO.puts("opt_or42(5)            = #{inspect(Hxler.Math.opt_or42(5))}  (want 5)")

try do
  Hxler.Math.add("x", 1)
rescue
  e -> IO.puts("add(\"x\",1) badarg      = #{inspect(e)}  (want ArgumentError)")
end

# panic path: Haxe exception inside a NIF body -> :nif_panicked
# (sum64 with a Float arg decodes fine; use map_sum on an atom-keyed map:
#  String decode of the key atom fails -> badarg, so instead force a panic
#  via atom_text on a binary: asAtom is null -> BadArg... raw path. The
#  panic path was already E2E-proven in phases 0-3.)

# --- parallel + dirty sanity on the macro-generated table ---
tasks =
  for i <- 1..16 do
    Task.async(fn ->
      Enum.reduce(1..20_000, 0, fn n, acc -> Hxler.Math.add(n, i) + acc end)
    end)
  end

r = Task.await_many(tasks, 60_000)
IO.puts("parallel 16 x 20k add  OK, first = #{hd(r)}")

fibs =
  for _ <- 1..10 do
    Task.async(fn -> Hxler.Math.fib(200_000) end)
  end

fr = Task.await_many(fibs, 120_000)
IO.puts("dirty fib x10 parallel OK (results unique: #{Enum.uniq(fr) |> length()})")

IO.puts("PHASE4 SPIKE DONE")
