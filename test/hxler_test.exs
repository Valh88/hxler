defmodule HxlerTest do
  use ExUnit.Case, async: false

  alias Hxler.Math, as: M

  # E2E through the NIF compiled from native/math and loaded by Hxler.Math.

  # -- phase 4: plain types -------------------------------------------------
  test "add" do
    assert M.add(1, 2) == 3
    assert M.add(-5, 10) == 5
  end

  test "sum64 (64-bit)" do
    assert M.sum64(2_000_000_000, 2_000_000_000) == 4_000_000_000
  end

  test "greet" do
    assert M.greet("hx") == "Hello, hx!"
  end

  test "fib (dirty_cpu)" do
    assert M.fib(10) == 55
    assert M.fib(20) == 6765
  end

  test "safe_div naked term / error" do
    assert M.safe_div(10, 2) == 5
    assert M.safe_div(1, 0) == {:error, :zero_division}
  end

  test "atom_text (raw NIF)" do
    assert M.atom_text(:hello) == "hello"
    assert_raise ArgumentError, fn -> M.atom_text(42) end
  end

  test "list_sum" do
    assert M.list_sum([1, 2, 3, 4]) == 10
  end

  test "map_sum" do
    assert M.map_sum(%{"a" => 1, "b" => 2}) == 3
  end

  test "both (bool + float)" do
    assert M.both(true, 2.5) == 5.0
    assert M.both(false, 2.5) == 2.5
  end

  test "opt_or42 (nil -> default)" do
    assert M.opt_or42(nil) == 42
    assert M.opt_or42(7) == 7
  end

  # -- phase 5: resources --------------------------------------------------
  test "resource round trip + dtor" do
    arc = M.accum_new()
    assert M.is_accum(arc)
    assert M.accum_len(arc) == 0

    for i <- 1..10 do
      M.accum_push(arc, i)
    end

    assert M.accum_len(arc) == 10
    assert M.accum_sum(arc) == 55
    refute M.is_accum(123)
  end

  test "resource not a resource" do
    assert M.accum_new() |> M.is_accum()
    assert M.is_accum(:not_an_accum) == false
  end

  test "multiple independent resources do not interfere" do
    a = M.accum_new()
    b = M.accum_new()

    for i <- 1..10, do: M.accum_push(a, i)
    for i <- 1..3, do: M.accum_push(b, i)

    assert M.accum_len(a) == 10
    assert M.accum_sum(a) == 55
    assert M.accum_len(b) == 3
    assert M.accum_sum(b) == 6
  end

  test "native state survives across calls (mutations persist)" do
    acc = M.accum_new()
    assert M.accum_sum(acc) == 0

    M.accum_push(acc, 7)
    M.accum_push(acc, 35)
    assert M.accum_sum(acc) == 42

    M.accum_push(acc, 99)
    assert M.accum_sum(acc) == 141
  end

  test "rustler-style badarg on a non-resource term" do
    # a non-resource term must not be accepted where a resource is expected
    assert_raise ArgumentError, fn -> M.accum_sum(123) end
    refute M.is_accum(123)
  end

  test "resources are reclaimed after GC (dtor path)" do
    # keep one alive and hammer VM allocation/collection; short-lived arcs
    # are finalised by the hxcpp finalizer -> enif_release_resource -> dtor
    live = M.accum_new()

    for _ <- 1..200 do
      short = M.accum_new()
      for i <- 1..50, do: M.accum_push(short, i)
      if M.accum_sum(short) != 1275, do: flunk("bad sum in short-lived arc")
      :erlang.garbage_collect()
    end

    assert M.accum_sum(live) == 0
  end

  # -- phase 6: owned env + pids -------------------------------------------
  test "pid type / alive" do
    assert M.pid_type(self()) == :pid
    assert M.pid_type(123) == :not_pid
    assert M.pid_alive(self())

    dead = spawn(fn -> :ok end)
    Process.exit(dead, :kill)
    ref = Process.monitor(dead)
    assert_receive {:DOWN, ^ref, :process, ^dead, _}, 1000
    assert M.pid_alive(dead) == false
  end

  test "send_msg cross-process" do
    parent = self()

    receiver =
      spawn(fn ->
        receive do
          msg -> send(parent, {:got, msg})
        end
      end)

    assert M.send_msg(receiver, "hi-nif") == :ok
    assert_receive {:got, {:from_nif, "hi-nif"}}
  end

  test "send_msg bad pid -> error" do
    assert M.send_msg(123, :x) == {:error, :bad_pid}
  end

  test "send_msg carries complex payload through the owned env" do
    parent = self()

    receiver =
      spawn(fn ->
        receive do
          msg -> send(parent, {:got, msg})
        end
      end)

    payload = {:foo, [1, 2, 3], "héllo"}
    assert M.send_msg(receiver, payload) == :ok

    # payload crossed the BEAM boundary via enif_send and comes back identical
    assert_receive {:got, {:from_nif, {:foo, [1, 2, 3], "héllo"}}}
  end

  test "saved_term_gens" do
    assert M.saved_term_gens() == {true, false, true}
  end

  test "saved_term_load" do
    assert M.saved_term_load() == {:ok, 777}
  end

  test "make_ref_nif" do
    assert {:ok, ref} = M.make_ref_nif()
    assert is_reference(ref)
  end

  test "whereis_alive" do
    name = :"hxler_e2e_whereis_#{System.unique_integer([:positive])}"
    pid = spawn(fn -> Process.sleep(:infinity) end)
    Process.register(pid, name)
    assert M.whereis_alive(name) == true
    Process.unregister(name)
    assert M.whereis_alive(name) == false
    Process.exit(pid, :kill)
  end

  # -- parallel stress -----------------------------------------------------
  test "parallel arith stress" do
    results =
      1..8
      |> Task.async_stream(fn _ -> M.fib(20) end, max_concurrency: 2, timeout: 60_000)
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, 6765}, &1))
  end
end
