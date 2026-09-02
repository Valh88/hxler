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
end

a = Hxler.Math.accum_new()
IO.puts("accum_new              = #{inspect(a)}")
r1 = Hxler.Math.accum_push(a, 5)
IO.puts("accum_push(a,5)        = #{inspect(r1)}")
r2 = Hxler.Math.accum_push(a, 7)
IO.puts("accum_push(a,7)        = #{inspect(r2)}")
IO.puts("accum_len(a)           = #{inspect(Hxler.Math.accum_len(a))}")
IO.puts("accum_sum(a)           = #{inspect(Hxler.Math.accum_sum(a))}")
IO.puts("is_accum(a)            = #{inspect(Hxler.Math.is_accum(a))}")
