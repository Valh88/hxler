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
  def diag_roundtrip(), do: :erlang.nif_error(:nif_library_not_loaded)
  def diag_obj_null(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def diag_push_local(_a, _v), do: :erlang.nif_error(:nif_library_not_loaded)
  def diag_len(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def diag_count(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def diag_addr(_a), do: :erlang.nif_error(:nif_library_not_loaded)
end

a = Hxler.Math.accum_new()
IO.puts("addr(a)  1st           = #{Hxler.Math.diag_addr(a)}")
Hxler.Math.diag_push_local(a, 5)
Hxler.Math.diag_push_local(a, 7)
IO.puts("addr(a)  after pushes  = #{Hxler.Math.diag_addr(a)}  (same as 1st?)")
IO.puts("diag_count(a)          = #{inspect(Hxler.Math.diag_count(a))}  (want 2)")
IO.puts("diag_len(a)            = #{inspect(Hxler.Math.diag_len(a))}  (want 2)")
