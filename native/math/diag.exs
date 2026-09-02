defmodule Hxler.Math do
  @on_load :load_nif
  def load_nif do
    :code.purge(__MODULE__)
    :erlang.load_nif("D:/projects/elixir/hxler/native/math/bin/cpp/Main", 0)
  end

  def atom_text(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def add(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_new(), do: :erlang.nif_error(:nif_library_not_loaded)
end

IO.puts("atom_text(:hello)      = #{inspect(Hxler.Math.atom_text(:hello))}")
IO.puts("add(20,22)             = #{inspect(Hxler.Math.add(20, 22))}")
IO.puts("accum_new              = #{inspect(Hxler.Math.accum_new())}")
