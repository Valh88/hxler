# The hxcpp multi-thread GC can deadlock when BEAM schedulers race into the
# NIF concurrently (see hxler AGENTS.md, "Ключевая ловушка E2E"). Pinning the
# schedulers keeps the tests deterministic.
:erlang.system_flag(:schedulers_online, 1)

ExUnit.start()
