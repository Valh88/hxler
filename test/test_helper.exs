# The multi-thread hxcpp GC can deadlock when its single global lock is
# contended across parallel BEAM schedulers (known flake, see AGENTS.md).
# Pinning to one online scheduler makes the suite deterministic. The
# parallel stress test still exercises concurrency through dirty_cpu/fib
# across Task workers.
:erlang.system_flag(:schedulers_online, 1)

ExUnit.start()
