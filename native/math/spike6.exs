# Phase 6 E2E: owned env, SavedTerm, send/self/whereis, make_ref.
defmodule Hxler.Math do
  @on_load :load_nif
  def load_nif do
    :code.purge(__MODULE__)
    :erlang.load_nif("D:/projects/elixir/hxler/native/math/bin/cpp/Main", 0)
  end

  # ---- phase 0-4 stateless (kept so the NIF loads) ----
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

  # ---- phase 5 resources ----
  def accum_new(), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_push(_a, _v), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_sum(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def accum_len(_a), do: :erlang.nif_error(:nif_library_not_loaded)
  def is_accum(_t), do: :erlang.nif_error(:nif_library_not_loaded)

  # ---- phase 6 ----
  def pid_type(_t), do: :erlang.nif_error(:nif_library_not_loaded)
  def pid_alive(_t), do: :erlang.nif_error(:nif_library_not_loaded)
  def send_msg(_t, _p), do: :erlang.nif_error(:nif_library_not_loaded)
  def saved_term_gens(), do: :erlang.nif_error(:nif_library_not_loaded)
  def saved_term_load(), do: :erlang.nif_error(:nif_library_not_loaded)
  def make_ref_nif(), do: :erlang.nif_error(:nif_library_not_loaded)
  def whereis_alive(_name), do: :erlang.nif_error(:nif_library_not_loaded)
end

IO.puts("PHASE 6 SPIKE")
IO.puts("add(20,22) sanity    = #{Hxler.Math.add(20, 22)}  (want 42; NIF loaded)")

# ---- pid_type: decode a pid term vs not-a-pid ----
me = self()
IO.puts("pid_type(self())     = #{Hxler.Math.pid_type(me)}  (want :pid)")
IO.puts("pid_type(:hello)     = #{Hxler.Math.pid_type(:hello)}  (want :not_pid)")

# ---- pid_alive: live vs dead process ----
IO.puts("pid_alive(self())    = #{Hxler.Math.pid_alive(me)}  (want true)")
gut =
  spawn(fn ->
    Process.sleep(50)
  end)
IO.puts("pid_alive(spawned)   = #{Hxler.Math.pid_alive(gut)}  (want true)")
Process.sleep(100)
IO.puts("pid_alive(dead)      = #{Hxler.Math.pid_alive(gut)}  (want false)")

# ---- send from NIF via OwnedEnv: receiver awaits {:from_nif, payload} ----
parent = self()
receiver =
  spawn(fn ->
    receive do
      {:from_nif, p} -> send(parent, {:got, p})
    after
      2000 -> send(parent, :timeout)
    end
  end)

IO.puts("send_msg result      = #{inspect(Hxler.Math.send_msg(receiver, "hi-nif"))}  (want :ok)")

got =
  receive do
    {:got, p} -> p
    :timeout -> :TIMEOUT
  after
    3000 -> :RECV_TIMEOUT
  end
IO.puts("receiver got         = #{inspect(got)}  (want \"hi-nif\")")

# send to a non-pid term -> {:error, :bad_pid}
IO.puts("send_msg(:no)        = #{inspect(Hxler.Math.send_msg(:not_a_pid, 1))}  (want {:error, :bad_pid})")

# ---- SavedTerm generation semantics (NifResult<Term> applies the term
#      directly, so the bare 3-tuple is expected) ----
IO.puts("saved_term_gens()    = #{inspect(Hxler.Math.saved_term_gens())}  (want {true, false, true})")

# ---- SavedTerm.load cross-env copy ----
IO.puts("saved_term_load()    = #{inspect(Hxler.Math.saved_term_load())}  (want {:ok, 777})")

# ---- make_ref ----
ref = Hxler.Math.make_ref_nif()
IO.puts("make_ref_nif()       = #{inspect(ref)}  (want {:ok, ref})")
rx = case ref do {:ok, r} when is_reference(r) -> true; _ -> false end
IO.puts("is a {:ok, ref}      = #{rx}  (want true)")

# ---- whereis: registered name lookup + alive check ----
Process.register(me, :nif_test_proc)
IO.puts("whereis_alive()      = #{Hxler.Math.whereis_alive(:nif_test_proc)}  (want true)")
IO.puts("whereis_alive(unreg) = #{Hxler.Math.whereis_alive(:nope_nope)}  (want false)")

IO.puts("PHASE6 SPIKE DONE")