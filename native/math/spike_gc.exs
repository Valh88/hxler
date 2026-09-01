# GC boundary stress: hxcpp collections running DURING parallel NIF calls.
defmodule Hxler.Spike.Math do
  @on_load :load_nif
  def load_nif do
    :code.purge(__MODULE__)
    :erlang.load_nif("D:/projects/elixir/hxler/native/math/bin/cpp/Entry", 0)
  end

  def add(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def add64(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def haxe_add(_a, _b), do: :erlang.nif_error(:nif_library_not_loaded)
  def panic(), do: :erlang.nif_error(:nif_library_not_loaded)
  def gc_now(), do: :erlang.nif_error(:nif_library_not_loaded)
  def alloc(_n), do: :erlang.nif_error(:nif_library_not_loaded)
end

_ = Hxler.Spike.Math.add(1, 2) # boot

# sanity: alloc(100) => sum(0..99)=4950 + len("spike-4950")=10 => 4960
IO.puts("alloc(100)    = #{inspect(Hxler.Spike.Math.alloc(100))}  (want 4960)")
:ok = Hxler.Spike.Math.gc_now()
IO.puts("gc_now()      = :ok (forced hxcpp major collect from BEAM thread)")

# --- storm: 16 worker tasks hammering alloc (forces collects), 2 more tasks
# --- repeatedly force major collects from BEAM threads concurrently
workers =
  for i <- 1..16 do
    Task.async(fn ->
      Enum.reduce(1..30_000, 0, fn n, acc ->
        rem(Hxler.Spike.Math.alloc(200) + Hxler.Spike.Math.add(n, i) + acc, 2_147_483_647)
      end)
    end)
  end

gcers =
  for _ <- 1..2 do
    Task.async(fn ->
      for _ <- 1..200 do
        Hxler.Spike.Math.gc_now()
        :timer.sleep(5)
      end
    end)
  end

results = Task.await_many(workers, 120_000)
Task.await_many(gcers, 120_000)
IO.puts("GC storm: 16 workers x 30k allocs + 2x200 forced collects OK, first = #{hd(results)}")

IO.puts("SPIKE-GC DONE")
