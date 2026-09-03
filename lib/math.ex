defmodule Hxler.Math do
  @moduledoc """
  Demo/example NIF module backed by the `native/math` Haxe fixture.

  Functions: arithmetic (`add/2`, `sum64/2`), strings (`greet/1`), lists
  (`list_sum/1`), maps (`map_sum/1`), option (`opt_or42/1`), mixed
  (`both/2`), dirty_cpu (`fib/1`), error handling (`safe_div/2`), raw NIF
  (`atom_text/1`), arity-overload (`same_name/1`, `same_name/2`), resources
  (`accum_new/0`, `accum_push/2`, `accum_sum/1`, `accum_len/1`,
  `is_accum/1`), and owned env/pids (`pid_type/1`, `pid_alive/1`,
  `send_msg/2`, `saved_term_gens/0`, `saved_term_load/0`, `make_ref_nif/0`,
  `whereis_alive/1`).
  """

  use Hxler, otp_app: :hxler, nif: :math
end
