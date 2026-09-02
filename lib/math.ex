defmodule Hxler.Math do
  @moduledoc """
  Demo/example NIF module backed by the `native/math` Haxe fixture.

  Functions: arithmetic (`add/2`, `sum64/2`), strings (`greet/1`), lists
  (`list_sum/1`), maps (`map_sum/1`), option (`opt_or42/1`), mixed
  (`both/2`), dirty_cpu (`fib/1`), error handling (`safe_div/2`), raw NIF
  (`atom_text/1`), resources (`accum_new/0`, `accum_push/2`, `accum_sum/1`,
  `accum_len/1`, `is_accum/1`), and owned env/pids (`pid_type/1`,
  `pid_alive/1`, `send_msg/2`, `saved_term_gens/0`, `saved_term_load/0`,
  `make_ref_nif/0`, `whereis_alive/1`).
  """

  use Hxler, otp_app: :hxler, nif: :math

  # -- phase 4: plain types -----------------------------------------------
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def sum64(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def greet(_name), do: :erlang.nif_error(:nif_not_loaded)
  def fib(_n), do: :erlang.nif_error(:nif_not_loaded)
  def safe_div(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def atom_text(_t), do: :erlang.nif_error(:nif_not_loaded)
  def list_sum(_items), do: :erlang.nif_error(:nif_not_loaded)
  def map_sum(_m), do: :erlang.nif_error(:nif_not_loaded)
  def both(_b, _f), do: :erlang.nif_error(:nif_not_loaded)
  def opt_or42(_v), do: :erlang.nif_error(:nif_not_loaded)

  # -- phase 5: resources -------------------------------------------------
  def accum_new(), do: :erlang.nif_error(:nif_not_loaded)
  def accum_push(_arc, _v), do: :erlang.nif_error(:nif_not_loaded)
  def accum_sum(_arc), do: :erlang.nif_error(:nif_not_loaded)
  def accum_len(_arc), do: :erlang.nif_error(:nif_not_loaded)
  def is_accum(_t), do: :erlang.nif_error(:nif_not_loaded)

  # -- phase 6: owned env + pids ------------------------------------------
  def pid_type(_t), do: :erlang.nif_error(:nif_not_loaded)
  def pid_alive(_t), do: :erlang.nif_error(:nif_not_loaded)
  def send_msg(_target, _payload), do: :erlang.nif_error(:nif_not_loaded)
  def saved_term_gens(), do: :erlang.nif_error(:nif_not_loaded)
  def saved_term_load(), do: :erlang.nif_error(:nif_not_loaded)
  def make_ref_nif(), do: :erlang.nif_error(:nif_not_loaded)
  def whereis_alive(_name), do: :erlang.nif_error(:nif_not_loaded)
end
