defmodule D1 do
  @on_load :load_nif
  def load_nif do
    :code.purge(__MODULE__)
    :erlang.load_nif("D:/projects/elixir/hxler/native/math/bin/cpp/Main", 0)
  end
  def atom_text(_a), do: :erlang.nif_error(:nif_library_not_loaded)
end
case :erlang.load_nif("D:/projects/elixir/hxler/native/math/bin/cpp/Main", 0) do
  {:error, {reason, text}} -> IO.puts("reload: #{inspect(reason)} #{inspect(text)}")
  other -> IO.inspect(other)
end
IO.puts("atom_text(:hello)      = #{inspect(D1.atom_text(:hello))}")
