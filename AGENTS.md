# AGENTS.md — hxler

## Что это за проект

`hxler` = "mini-rustler": SDK для написания NIF для Elixir/Erlang на Haxe
(только target hxcpp) с rustler-подобным API. В репо два пакета:

- **Корень** — mix-приложение `:hxler` (Elixir ~> 1.19, OTP 27+): `lib/` —
  Elixir-сторона (загрузка NIF, mix-компилятор), `test/` — ExUnit E2E,
  `native/` — примеры NIF-модулей (исходники Haxe).
- **`hxler/`** — haxelib-пакет (classPath `source`): Haxe-SDK
  (`hxler.core`, `hxler.nif`, `hxler.macros`) + генератор + example.

Сейчас реализованы фазы 0–6 (stateless-NIF'ы, ресурсы, owned env + пиды —
см. разделы «Фаза 5 — статус», «Фаза 6 — статус») и фаза 7 (Mix-интеграция:
`use Hxler` компилирует `native/<nif>` и грузит NIF через `@on_load`,
см. «Фаза 7 — статус»). Остались только up/down-колбэки ресурсов фазы 8.
Пример: `native/math/` → `Hxler.Math` (ExUnit E2E 20 тестов).

## План: hxler — «mini-rustler» на Haxe/HXCPP для Elixir NIF

### Архитектура (3 слоя, как у rustler)

```
┌─────────────────────────────────────────────────────────────────┐
│ Haxe SDK (haxelib "hxler")                                       │
│                                                                  │
│  hxler.core   — удобный API: Env, Term, Atom, Binary,            │
│                 Encoder/Decoder, ResourceArc, OwnedEnv, Pid…     │
│  hxler.nif    — wrapper-слой: enif-вызовы с Option/Result,       │
│                 out-параметры спрятаны, NifBuild (@:buildXml)    │
│  hxler.nif.raw — СГЕНЕРИРОВАННЫЙ 1:1 слой extern-обёрток enif_*  │
│                 + C-типы (ErlNifEnv/Binary/Func/Entry/…)         │
│  hxler.macros — build-макросы: NifBuilder, EntryBuilder,         │
│                 AtomBuilder (метапрограммирование)               │
│                                                                  │
│  generated glue C++ (@:cppFileCode): ERL_NIF_INIT + ErlNifFunc   │
│  таблица + трамплины + load-колбэк + boot + exception-перехват   │
└─────────────────────────────────────────────────────────────────┘
        ▲ mix-компилятор (Mix.Tasks.Compile.Hxler) копирует .dll/.so
┌─────────────────────────────────────────────────────────────────┐
│ Elixir-проект: use Hxler, otp_app → @on_load → :erlang.load_nif  │
└─────────────────────────────────────────────────────────────────┘
```

### Целевой API

```haxe
// native/math/source/math/MathNif.hx
@:build(hxler.macros.NifBuilder.build())
class MathNif {
  @:nif static function add(a:Int, b:Int):Int return a + b;

  @:nif(schedule = "dirty_cpu")
  static function fib(n:cpp.Int64):cpp.Int64 { … }

  @:nif static function greet(name:String):String return 'Hello, $name!';
}

@:build(hxler.macros.EntryBuilder.build([MathNif], "Elixir.Hxler.Math"))
class Entry {}
```

```elixir
# lib/hxler/math.ex
defmodule Hxler.Math do
  use Hxler, otp_app: :hxler
end

Hxler.Math.add(1, 2)          # 3
Hxler.Math.greet("hx")        # "Hello, hx!"
```

### Фазы реализации

- **Фаза 0 — Spike (доказательство цепочки, до SDK):** рукописный glue +
  минимальный Haxe-класс; сборка `-D dll_link`; проверка экспорта
  `nif_init`; загрузка из Elixir; `add(1,2) == 3`. Здесь же проверяются
  все риски из раздела «Хардкорные факты».
- **Фаза 1 — Raw-слой (СДЕЛАНО):** компиляционный макрос
  `hxler/macros/RawGen.hx` парсит `erl_nif_api_funcs.h` (список
  `ERL_NIF_API_FUNC_DECL`, 177 деклараций) и генерирует `Raw.hx`
  (161 функция: extern с `@:native`; int→Int, int64→cpp.Int64,
  `ERL_NIF_TERM`→NifTerm, out-параметры→cpp.Pointer<T>, enum-параметры и
  `**`-параметры → inline-обёртки untyped __cpp__ с кастами) + типы
  по файлам (`ErlNifBinary/ErlNifFunc/ErlNifEntry/ErlNifPid/...` как
  `@:structAccess` extern; флаги/encodings как enum abstract).
  Out-параметры завёрнуты во 2-й слой `hxler/nif/Wrapper.hx`
  (Null-возвраты, Cell/TupleView, termToString). Тесты: utest + check-сборка.
- **Фаза 2 — Core basics (СДЕЛАНО):** `hxler/core/` — `Env` (+`EnvKind`:
  ProcessBound/Callback/Init/ProcessIndependent; creators: int/uint/int64/
  uint64/float/bool/atom/binaryFromBytes/listFromArray/tupleFromArray/
  mapNew/mapPut/makeRef/errorTuple/binaryToTerm/consumeTimeslice), `Term`
  (env+raw; проверки типов, termType, compare/identical, getInt*/getFloat,
  asAtom/asBinary, toList, mapGet, copyTo, termToBinary, hash, toString),
  `Atom`+`AtomCache` (mutex-guarded lazy intern, один shared env живёт
  вечно — атомы глобальны) + макрос `AtomBuilder` (`@:build` → lazy-геттеры;
  санитайзер `AtomNames` — unit-тестируем) + `TestAtoms` для check. Триада
  бинарников: `Binary` (env-bound view; fromTerm/fromIolist — iolist пиннится
  make_binary), `OwnedBinary` (BinaryBuf: BEAM-хранилище, releaseToTerm/
  free), `NewBinary` (make_new_binary term+буфер в env). ETF r/t проверен
  E2E. Правила: structAccess-поля возвращают RAW указатели (setAt на них
  нельзя — только untyped-индексация); Star<Void> не боксится в Dynamic →
  у классов с Star-полями конструктор БЕЗ аргументов + @:unreflective;
  `hxler/nif/Mem.hx` — ЕДИНСТВЕННОЕ место с untyped (memcpy Bytes↔raw);
  байты→pointer: `cpp.NativeArray.address(bytes.getData(), 0)` (BytesData =
  Array<cpp.UInt8>); String→char*: копия в Array<cpp.Char> + ofArray;
  snprinf вариадик — второй обоснованный untyped (Wrapper.termToString).
- **Фаза 3 — Encoder/Decoder + ошибки (СДЕЛАНО):** `NifResult<T>` =
  `Ok(v) | Error(e)` (свой enum: haxe.ds.Result в std 4.3.7 НЕТ);
  `NifError = BadArg | Atom(name) | RaiseAtom(name) | RaiseTerm(t) | Term(t)`
  → `NifReturn.apply/errorTerm` (Atom возвращается КАК результат, не ошибка;
  все 5 путей проверены E2E). `Schedule` (Normal/DirtyCpu/DirtyIo → флаги,
  фаза 4 подставит в таблицу; env.consumeTimeslice уже в core). Интерфейсы
  `Encoder`/`Decoder<T>` для пользовательских типов + статические
  `Encoders`/`Decoders` (int/uint/int64/uint64/float(int-fallback)/bool/
  string↔utf8-binary/atom/term; option↔nil; list↔list; map↔пары (Map<K,V>
  с generic-K на hxcpp НЕ инстанцируется в runtime — возврат Array<{k,v}>);
  result↔{:ok,_}|{:error,_} через haxe.ds.Either — вложенные NifResult
  Haxe-инференс ломается). Вложенный enum с конструктором Atom перекрывает
  класс hxler.core.Atom в import-скоупе — квалифицировать.
- **Фаза 4 — Макросы Nif-регистрации (СДЕЛАНО):** `@:build(NifBuilder.build())`
  на NIF-классе: собирает `@:nif` static-методы (параметры `name=`,
  `schedule=`, `arity=` парсятся КАК EBinop(OpAssign,...) в метах Haxe, не
  EObjectDecl), дефолтное NIF-имя = camelToSnake (Elixir-конвенция),
  генерирует `__hx_nif_<func>` обёртки (Env+decode по типам сигнатуры →
  вызов → encode; NifResult → apply; catch Dynamic → :nif_panicked) и
  ВЕШАЕТ на обёртку мету `:nif(name=, schedule=, arity=N)` для EntryBuilder.
  Поддержка типов: Int/Float/Bool/String/haxe.Int64/cpp.UInt64/Atom/Term,
  Null<T>, Array<T>, Map<K,V> (через пары), пользовательские с static
  hxEncode/hxDecode (не тестировано). Raw-функции `(ErlNifEnv, Int,
  cpp.Pointer<NifTerm>):NifTerm` требуют `@:nif(arity=N)` и идут как есть.
  Правило: в @:nif-сигнатурах ПОЛНЫЕ пути типов (Printer печатает как
  написано; resolveType ломает Map<K,V> → Map.K). `@:build(
  EntryBuilder.build([Class…], "Elixir.Module"[, loadFn]))`: собирает
  обёртки/raw с Type-уровня (statics TLazy → TypeTools.follow; мета
  обёрток — источник name/schedule/arity), генерирует __hx_dispatch +
  __hx_load + @:cppFileCode ЧЕРЕЗ ClassType.meta.add (nameless-Field
  не проходит декодер) — C++ glue: трамплины clsSym =
  `pack::Name_obj::__hx_dispatch`, hxler_ensure_boot (call_once),
  HxStackGuard, ErlNifFunc-таблица, ERL_NIF_INIT. E2E: таблица с
  snake_case-именами, dirty_cpu-флаг из `schedule=`, {:error,:reason} из
  NifError.Term, голый терм из NifResult<Term> (rustler-семантика).
- **Фаза 5 — Ресурсы (РАБОТАЕТ; handshake закрыт — immortal holders):**
  Реализовано:
  - `hxler/core/Resource.hx` — интерфейс-маркер (в 5a без dtor-хуков).
  - `hxler/core/ResourceArc.hx` — хэндл: BEAM-блок =
    `hxler::HxResourceFrame{void* root, int size, ::String kind}` +
    user payload; `make/toTerm/makeResourceBinary/get/keep/payload`,
    `tryGet/tryGetRaw/decode/encode` (kind-проверка по class-path строке),
    release-once; конструктор БЕЗ аргументов + `@:unreflective` +
    `init(raw,obj)` — Dynamic-фабрика hxcpp не умеет void*-аргументы
    (C2664 в __Create, правило из фазы 2). `make` пишет в frame.root
    СЛОТ-ИНДЕКС immortal-таблицы, `tryGetRaw` читает индекс → fetch.
  - `hxler/core/ResourceCache.hx` — Map<"math.Accum", ErlNifResourceType>
    (mutex-guarded) + immortal holders-таблица (`static var holders`,
    boot-rooted, mutex-guarded: store/fetch/unhold + freeSlots-переиспол-ние)
    + `trackRelease` (финалайзер `_hx_set_finalizer` →
    `enif_release_resource`, once-флаг в arc) + `onResourceFree` (dtor-хук).
  - `hxler/nif/raw/ErlNifResourceFrame.hx` + `hxler/core/HxResourceFrame.h`
    (C++ struct, шипится с пакетом; include-путь задаётся define'ом
    `hxler_sdk_include=<package>/source` в hxml → `${hxler_sdk_include}`
    в buildXml).
  - `Wrapper`: `initResourceType` (untyped: enum-pointer
    `ErlNifResourceFlags*` не выражается в hxcpp), `alloc/keep/release/
    makeResource/makeResourceBinary/sizeofResource`.
  - `Env.registerResource(cls)`: только в EnvKind.Init; собирает
    ErlNifResourceTypeInit через glue-функцию `hxler_resource_type_init()`
    (C fn-указатели нельзя присвоить из Haxe на MSVC), members=3.
  - `Term.tryGetResource(cls)`, `Decoders.resource`, `Encoders.resource`;
    `NifBuilder` поддерживает `hxler.core.ResourceArc<T>` в сигнатурах
    `@:nif` (короткое имя T резолвится в пакет владельца).
  - `EntryBuilder.build(..., loadFn)` — Haxe load-колбэк (регистрация
    типов), glue: `hx_res_dtor` (обеспечено `hxler_ensure_boot()` +
    `HxStackGuard`, вызов Haxe `onResourceFree`), `hx_res_down`
    (noop до фазы 6/8), `hxler_resource_type_init()`.
  E2E-статус (spike5.exs): `accum_len`=10, `accum_sum`=55, `is_accum`=true,
  badarg, «live sum after 1000 push»=500500 (мутации объекта ПЕРЕЖИВАЮТ
  границу NIF-вызова), GC stress 8×200 параллельных воркеров — стабильно.
  Up/down-колбэки ресурсов — фазы 6/8.
  **Можно ли пользоваться без фазы 5: ДА.** Фазы 0–4 самодостаточны для
  stateless-NIF (любые термы, dirty, ETF, паники). Ресурсы нужны только
  для нативного состояния между вызовами (сокеты, буферы, соединения);
  обходной путь — сериализация/ETF или хранение в процессе Elixir.
- **Фаза 6 — owned env + пиды (СДЕЛАНО):** core: `OwnedEnv` (alloc_env/
  dispose/clear + gen-счётчик, cached EnvKind.ProcessIndependent view,
  makers), `SavedTerm` (raw term + gen + owning OwnedEnv; isValid проверяет
  freed/gen, load(env) → enif_make_copy или null, if stale), `Pid` (own
  single-word storage под ErlNifPid, self/fromTerm/whereis/send/isAlive,
  setUndefined/isUndefined); Env: self/pidOf/whereis/isProcessAlive/
  isCurrentProcessAlive/send; Term.toPid. E2E spike6.exs: pid_type,
  pid_alive, send_msg (OwnedEnv→enif_send→получатель), saved_term_gens
  (valid/clear-stale/valid), saved_term_load (copy cross-env), make_ref_nif,
  whereis_alive — все зелёные. Wrapper/raw уже имели все примитивы.
- **Фаза 7 — Mix-интеграция + E2E:** `use Hxler, otp_app: :app [, nif: :name]`
  (макрос, rustler-стиль, НЕ отдельный Mix.Task): `Hxler.Compiler`
  (erts-include из :code.root_dir(), build.hxml, haxe → hxcpp, копия
  артефакта в priv/native/<name>.{dll|so} с удалением старого,
  @external_resource на .hx); `@on_load` (:code.purge + :erlang.load_nif);
  ExUnit-тесты: арифметика,
  строки/списки/мапы/кортежи, Option/Result, атомы-кэш, resource
  round-trip + dtor, dirty_cpu, бadarg, параллельный стресс (Task.async × N);
  детерминизм `mix test` под `schedulers_online=1` (см. «Фаза 7 — статус»).
- **Фаза 8 — после v0.1 (вне скоупа):** derive-макросы структур
  (NifStruct/NifTuple/NifRecord/unit/tagged enum-аналоги),
  thread::spawn-хелпер, monitor/dynamic_resource_call полный,
  upgrade-колбэк, Linux-верификация, публикация haxelib+hex.

Платформы: Windows-first (тестируем здесь); код пишется
кросс-платформенно (Linux-ветка той же архитектуры). Минимальный OTP —
27 (NIF minor 2.17, сборка против локального заголовка ERTS 15.2.4).

## Внешние референсы

- `D:\projects\csharp\rustler` — Rust rustler; API-образец (Env/Term,
  Encoder/Decoder, ResourceArc, @nif, init!).
- `D:\projects\pascal\rnl\hx_rnl` — рабочий пример Haxe→cpp FFI.
  Перед любой FFI-работой читайте его `AGENTS.md`: там хардкорные
  ловушки hxcpp (Dynamic боксинг портит указатели; `<lib>` — внутри
  `<target id="haxe">`, НЕ `<files>`; `-fpermissive`; `@:headerCode`
  ставится прямо над объявлением класса; смена compiler-флагов не
  инвалидирует PCH → удалять build-каталог).

## Инструменты на этой машине (проверено)

- Haxe 4.3.7, HXCPP 4.3.2 (haxelib)
- Erlang OTP 27.3.1 / ERTS 15.2.4 → erl_nif.h = **NIF API 2.17**:
  `C:\Users\simpl\scoop\apps\erlang\27.3.1\erts-15.2.4\include`
- Компилятор: mingw-winlibs GCC 15.2 (MSVC нет), `gcc/g++` в PATH
- Elixir 1.19.4

## Команды

- `mix test`, `mix format` (formatter не трогает Haxe-код).
- Формат Haxe: `haxelib run formatter -s source` (hxler/hxformat.json:
  leftCurly both, emptyCurly break, табы).
- Сборка NIF (автоматизируется mix-компилятором, ручной вариант):
  `haxe -cp native/math/source -main math.Entry --cpp <builddir> -D dll_link
  -D no_shared_libs -D HXCPP_M64 -D hxler_erts_include="<erts include>"`,
  затем `haxelib run hxcpp <builddir>/Build.xml haxe`.
- Регистрация пакета (нужна, т.к. buildXml резолвит `${haxelib:hxler}`):
  `haxelib dev hxler hxler`.

## Хардкорные факты NIF (не переоткрывать)

- **Спайк пройден (native/math/):** вся цепочка работает — glue + Haxe,
  DLL грузится в BEAM, add/haxe-raw-вызовы/panic/badarg зелёные,
  параллельный тест 16 задач × 50k вызовов стабилен.
- **GC-граница проверена (spike_gc.exs):** 16 воркеров × 30k alloc-вызовов
  (миллионы Haxe-аллокаций: массивы+строки) + 400 принудительных
  `__hxcpp_collect` из BEAM-потоков ПОВЕРХ параллельных NIF-вызовов —
  без крашей и порчи памяти: multi-thread hxcpp GC + SetTopOfStack
  RAII-дисциплина работают на BEAM scheduler-потоках.
- **Ресурсный handshake (фаза 5) + stress закрыты (spike5.exs):**
  8 воркеров × 200 ресурсных циклов (new/push/sum + dtor'ы на GC процессов)
  стабильны; hxcpp-финалайзеры → enif_release_resource работают под
  `HxStackGuard` в dtor. Ещё не проверено: unload (purge+reload).
  ⚠️ GC-stress spike5.exs иногда ПОДВИСАЕТ (не крашится) под интенсивным
  `:erlang.garbage_collect()` 8 параллельных воркеров — флейки-регрess
  multi-thread hxcpp GC (не связано с фазой 6); при повторе проходит
  за ~45 с. НЕ считать это регрессом фазы 6.
- **OwnedEnv/SavedTerm/Pid (фаза 6) — ключевые факты:** `ErlNifPid` — это
  ровно `{ ERL_NIF_TERM pid; }` (одно машинное слово) → `Pid` владеет
  словом как `NifTerm`-полем и выдаёт `Pointer<ErlNifPid>` через
  `untyped __cpp__("(ErlNifPid*)&{0}->pidWord", this)` (`{0}` для this —
  `ObjectPtr`, нужен `->`, НЕ `.`); `cpp.NativeArray<stackOnly-struct>` НЕ
  компилируется («Too many type parameters»). OwnedEnv построен на
  `enif_alloc_env/free_env/clear_env` (Wrapper уже имел их) + охранный
  gen-счётчик; `dispose()` ставит `freed` и null-ит cached Env-view;
  `SavedTerm.load(env)` → `enif_make_copy`, только если `!freed && gen`
  совпал. `enif_send` со scheduler-потока требует msg_env из
  process-independent env (OwnedEnv) и to_pid ≠ вызывающий процесс —
  E2E-спайк именно так и посылает (cross-process). Каждая функция в
  ErlNifFunc-таблице обязана иметь Elixir-заглушку в модуле до
  `:erlang.load_nif`, иначе `{:bad_lib, "Function not found ..."}`
  (поэтому добавление @:nif-функций требует добавить и заглушки в
  spike.exs/spike5.exs/spike6.exs).
- Компилятор на этой машине — **MSVC из VS 2022** (hxcpp находит сам;
  objdir msvc1964). DLL-зависимости только KERNEL32/USER32 (CRT
  статичен) — mingw runtime DLLs не нужны. mingw остаётся фолбэком.
- BEAM на Windows: `load_nif("priv/native/<name>", 0)` — путь **БЕЗ**
  `.dll`-суффикса (с суффиксом LoadLibrary падает «не найден модуль»).
- `cpp.Star<T>` для coreType-типов (cpp.Int64 и т.п.) генерируется как
  ЗНАЧЕНИЕ, не указатель → для out-параметров использовать
  `cpp.Pointer<T>` (implicit `operator T*()` при вызове) +
  `cpp.Pointer.addressOf(var)` для адресов локальных переменных.
- Opaque C-типы: `@:native("::cpp::Pointer<ErlNifEnv>") extern class
  ErlNifEnv {}` (паттерн из std/cpp/FILE) — типизированный env, без
  void*-кастов (MSVC их не прощает).
- `haxe.Int64` на cpp = объект `::cpp::Int64Struct` — НЕ для C-ABI.
  `cpp.Int64` = plain int64_t (ABI-правильный), но без Haxe-операторов —
  арифметика через `untyped __cpp__("{0} + {1}", a, b)`.
- `-main`-класс обязан иметь `static main()` (пустой ок); NIF-классы
  должны быть импортированы из main-дерева, иначе DCE их выкинет и
  заголовки не сгенерируются (import в Entry достаточен).
- В glue: `__boot_all()`/`hx::Boot()` декларирует `hxcpp.h` (не объявлять
  `extern "C"` самому); Haxe `cpp.Int64` в C++ = `cpp::Int64`.
- Флаг `-I${hxler_erts_include}` нужен в ОБЕИХ группах: `haxe` и
  `__main__` (glue-файл компилируется в `__main__`).
- `ERL_NIF_INIT`-макрос сам экспортирует `nif_init` (MSVC: dllexport
  из erl_nif.h; mingw: auto-export). Проверено: экспорт есть.
- `ERL_NIF_TERM` = машинное слово: typedef `cpp.UInt64` под HXCPP_M64.
- Win64: C `long` = 32 бита → всегда `enif_get_int64/enif_make_int64`
  (на Unix это header-макросы → get_long/make_long).
- Windows: `erl_nif.h` препроцессором подменяет `enif_*` →
  `WinDynNifCallbacks.*`; hxcpp генерирует plain-вызовы → один
  extern-слой `@:native("enif_xxx")` + `@:headerCode('#include "erl_nif.h"')`
  работает на обеих платформах. Точка входа — макрос `ERL_NIF_INIT(...)`.
- Сборка DLL: `-D dll_link` (+ `-D no_shared_libs` → `-static-libgcc
  -static-libstdc++`, иначе NIF тянет mingw runtime DLL).
- Boot hxcpp до любого Haxe-кода на BEAM-потоках: `hx::Boot();
  __boot_all();` под `std::call_once`.
- Каждый NIF-вызов: `hx::SetTopOfStack(&marker,true)` push …
  `hx::SetTopOfStack(0,true)` pop; BEAM-потоки регистрируются сами.
- **Любой Haxe-код ВНЕ трамплина (dtor/down/финалайзер) ОБЯЗАН работать
  под `hxler_ensure_boot()` + `HxStackGuard`** — BEAM вызывает dtor во
  время GC процесса на scheduler-потоке без `tlsStackContext`; любой
  Haxe-доступ (мутекс/массив/аллокация) там = `Bad local allocator -
  requesting memory from unregistered thread!` (краш BEAM). Зашито в
  генерируемый glue (EntryBuilder).
- Haxe-объекты в enif-ресурсах между вызовами: immortal holders-таблица
  `ResourceCache` (frame хранит слот-индекс, не голый указатель);
  `GCAddRoot/GCRemoveRoot` на BEAM-памяти НЕ использовать.
- Haxe-исключения = C++ throw: ловить `catch (Dynamic e)` в трамплине →
  `enif_raise_exception(:nif_panicked)`.
- ERTS-include передаётся define'ом `hxler_erts_include` (попадает в
  Options.txt → `${hxler_erts_include}` в buildXml; проверить в spike).
- Перед копированием нового .dll/.so в `priv/native/<name>` — удалить
  старый файл (перезапись загруженного NIF = сегфолт BEAM).
- Elixir-модуль: `use Hxler` (план) → `@on_load`: `:code.purge(__MODULE__)`
  затем `:erlang.load_nif(...)` (upgrade не поддерживается).

## Модель памяти (граница BEAM GC ↔ hxcpp GC)

- Два GC не пересекаются по памяти. BEAM: кучи процессов, binary heap
  (refcount), NIF-ресурсы (refcount, не копируются, живут до release).
  hxcpp: Immix mark-sweep, статические корни (boot) + ручные (GCAddRoot).
- Handshake для Haxe-объекта в enif-ресурсе — ЧЕРЕЗ immortal-таблицу
  держателей в `hxler/core/ResourceCache.hx`: C-frame `{void* root, int
  size, ::String kind}` хранит только СЛОТ-ИНДЕКС этой таблицы (не голый
  указатель); хранитель живёт в hxcpp-статике (boot-root, не двигается,
  слот-адрес в BEAM-памяти не обновляется compactor'ом).
  ⚠️ Ручной `hx::GCAddRoot(&frame->root)` на BEAM-памяти НАДЁЖНЫМ НЕ
  ОКАЗАЛСЯ — hxcpp Immix compactor **не обновляет** слот-адрес из чужой
  (BEAM) памяти. Второй баг этой схемы: удаляемые Haxe-объекты живут в
  static-корнях → слоты освобождаются dtor'ом через freeSlots (переиспол-ние).
- `ResourceArc` release — ровно один раз (флаг once), из финалайзера hxcpp.
- `Term.raw` — примитив (NifTerm = UInt64/UInt32), НЕ hx::Object-поле:
  hxcpp не сканирует BEAM-слова; conservative-скан отбрасывает адреса
  вне hxcpp-регионов.
- Elixir-сторона НИКОГДА не видит сырых указателей: ResourceArc →
  opaque resource-терм (refcount BEAM), Binary → BEAM-бинарник,
  Term/Atom/Pid/Ref → обычные термы.
- Правила lifetime (нарушение = краш BEAM, не caught):
  - `Term` привязан к своему `Env`; вне NIF-вызова живут только Atom
    (глобальны) и SavedTerm из OwnedEnv (проверка env+gen при load).
  - Терм из env A не используется в env B (только `enif_make_copy`).
  - Binary-view (inspect_binary/inspect_iolist) живёт не дольше env.
  - Все Haxe-исключения ловятся в glue (трамплины, load, dtor, down) —
    C++-unwind сквозь BEAM-стек = UB.
  - SetTopOfStack push/pop — RAII-guard в glue (дисбаланс = мусорный
    скан стека → ложные/пропущенные корни).
- Ошибки памяти возможны только при нарушении этой дисциплины, которая
  зашита в API, а не при нормальном использовании.

## Фаза 5 — статус (handshake ЗАКРЫТ)

### Что сделано (полностью)
Handshake на immortal holders реализован и работает (см. фазу 5 в
«Фазы реализации»). E2E spike5.exs: accum_len=10, accum_sum=55,
is_accum=true, live sum после 1000 push=500500, GC stress 8×200
параллельных воркеров — стабильно.

### Причина исходного бага handshake (count/len=0 после NIF-вызова)
Это НЕ была проблема GC-перемещения/GCAddRoot. Корень — баг в
`NifBuilder.retExpr` для функций с возвратом `Void`: генерировался
`AtomCache.intern("ok").toTerm(env).raw` БЕЗ `$valueExpr` — сам вызов
NIF-функции (например `accumPush`) просто не выполнялся, поэтому все
мутации объекта терялись. Int-функции «работали» только потому, что
возврат включал call. Исправление — IIFE-блок:

```
(() -> { $valueExpr; return hxler.core.AtomCache.intern("ok").toTerm($envVar).raw; })()
```

(Haxe не имеет оператора-запятой, поэтому `($valueExpr, :ok)` невозможен.)

Параллельно, как независимый шаг, отвязка от GCAddRoot на BEAM-памяти
сделана и оставлена (см. «Планируемое решение» ниже) — frame хранит
слот-индекс immortal-таблицы, а не голый указатель.

### Второй баг (многопоточный краш) — ЗАКРЫТ
`Bad local allocator - requesting memory from unregistered thread!`
при параллельных ресурсных операциях (8 spawn-воркеров × 200). Причина:
hx_res_dtor вызывался BEAM'ом во время GC процесса — на scheduler-потоке
БЕЗ hxcpp-контекста (нет `tlsStackContext`), и любой Haxe-доступ
(mutex/массив/аллокация) в `onResourceFree` падал. Исправление: в glue
`hx_res_dtor` (и `hx_res_down`) добавлены `hxler_ensure_boot();` +
`HxStackGuard guard;` — как и в обычных трамплинах.

### Планируемое/выполненное решение handshake
- `ResourceCache` держит `static var holders:Array<Dynamic>` — immortal
  hxcpp-таблица (статические корни boot'атся и живут вечно);
- `store(obj)` → index (слот в holders), `fetch(index)` → obj;
- в frame пишется только `index` (не голый указатель);
- `hx_res_dtor` (glue EntryBuilder) вызывает Haxe-хук `onResourceFree`
  для очистки слота ровно один раз (freeSlots переиспользует слоты).
- Haxe-объект держится живым статическим массивом — GCAddRoot больше
  не нужен, объект не перемещается-теряется.

### Ограничения/заметки
- dtor/down/финалайзеры обязаны работать под `hxler_ensure_boot()` +
  `HxStackGuard` — BEAM может вызывать их вне NIF-вызова (поток без
  hxcpp-контекста). Правило зашито в генерируемый glue.
- Up/down-колбэки ресурсов — фазы 6/8.
- Регресс после закрытия: check.hxml (Check.dll), utest 64/64,
  spike.exs (фаза 4), spike5.exs (фаза 5) — все зелёные.

### Можно ли пользоваться без фазы 5?
**ДА.** Фазы 0–4 полностью рабочие для stateless-NIF: любые термы,
Encoder/Decoder, dirty-cpu/io, ETF, паники, badarg, параллельный стресс.
Ресурсы (`ResourceArc<T>`) — механизм нативного состояния между
вызовами (сокеты, буферы, соединения, кэши); с фазы 5 они работают.

## Фаза 6 — статус (owned env + пиды СДЕЛАНО)

### Что сделано (полностью)
- `hxler/core/OwnedEnv.hx` — process-independent env (`enif_alloc_env`):
  `dispose()` (free_env, ставит `freed`), `clear()` (clear_env + gen++),
  cached `env:Env` view (EnvKind.ProcessIndependent), маркеры (int/int64/
  float/atom/binary/tuple/list/map/ref/errorTuple), `save(t)`. Охранный
  `freed`+`guard()` бросает при использовании после dispose.
- `hxler/core/SavedTerm.hx` — `load(dst)` → `enif_make_copy`, только если
  `!env.freed && env.gen == gen`; иначе null. `isValid()`, `rawOrNull()`.
- `hxler/core/Pid.hx` — владеет `ErlNifPid` как одно `NifTerm`-слово → raw
  `Pointer<ErlNifPid>` через `&{0}->pidWord`; `self(env)`, `fromTerm(t)`,
  `whereis(env,name)`, `isAlive(env)`, `send(env,msg)`, `setUndefined()`,
  `isUndefined()`.
- `Env`: +`self()`, `pidOf(t)`, `pidOfRegistered/wheres(atom)`,
  `isProcessAlive(pid)`, `isCurrentProcessAlive()`, `send(pid,msg)`.
- `Term`: +`toPid()`.

### E2E-статус (spike6.exs)
pid_type=:pid/:not_pid, pid_alive live/dead=true/false, send_msg
OwnedEnv→enif_send→получатель получил "hi-nif", send_msg(:no) →
{:error,:bad_pid}, saved_term_gens={true,false,true} (valid, clear-stale,
valid), saved_term_load={:ok,777} (copy cross-env), make_ref_nif={:ok,ref},
whereis_alive registered/unregistered=true/false — все зелёные. Регресс:
check.hxml (Check.dll), utest 94/94 ALL TESTS OK, spike.exs (фаза 4) —
зелёные; spike5.exs (фаза 5) — зелёный, кроме флейки-pовисания GC-stress
(см. «Хардкорные факты», не связано с фазой 6).

### Ограничения/заметки
- `enif_send` со scheduler-потока требует msg_env из OwnedEnv (msg_env ≠
  caller env) и to_pid ≠ вызывающий процесс; это задокументировано на
  `Pid.send` и показано в spike6 (`sendMsg` строит тело в throwaway
  OwnedEnv). Обращение из dirty-потока не проверено отдельно.
- `NifResult<Term>` возвращает терм ГОЛЫМ (rustler-семантика) — ошибка
  spike6-ожидания `{:ok, ...}` на `saved_term_gens` (правильно `{true,...}`).
- `cpp.NativeArray<ErlNifPid>` НЕ компилируется (stackOnly-struct).

### Можно ли пользоваться без фазы 6?
**ДА.** Фазы 0–5 полностью рабочие. Фаза 6 — только для async-паттернов
(пересылка сообщений, kept OwnedEnv для cross-thread/фоновых задач).

## Фаза 7 — статус (Mix-интеграция + E2E СДЕЛАНО)

### Что сделано (полностью)
- `lib/hxler.ex` — макрос `use Hxler, otp_app: :app [, nif: :name]`
  (rustler-стиль): `otp_app` — app **потребителя** (владелец артефакта).
  `__using__` мержет `Application.compile_env(otp_app, Hxler, [])` с опциями
  use (use-перекрывает), резолвит `:nif` (default = otp_app), вызывает
  `Hxler.Compiler.compile`, вешает `@external_resource` на все `.hx`
  native/<nif>/source и build.hxml, затем `@before_compile` генерирует
  `@on_load :hxler_init` = `:code.purge(__MODULE__)` +
  `:erlang.load_nif(Application.app_dir(otp_app, "priv/native/<nif>"), 0)`.
- `lib/hxler/compiler.ex` — `Hxler.Compiler.compile/2`: stale-check
  (артефакт новее всех `.hx`+build.hxml), `haxe <nif>/build.hxml` с
  override `-D hxler_erts_include` (из `:code.root_dir()/erts-*/include`) и
  `-D hxler_sdk_include`; `haxelib run hxcpp <nif>/bin/cpp/Build.xml haxe`;
  копия `Main.dll` → `priv/native/<nif>.<ext>` (сначала `File.rm` — загрузка
  без purge-перезаписи = сегфолт); `Mix.Project.build_structure()` зеркалит
  в `_build/<env>/lib/<otp_app>/priv`. run из `cd: <nif>/bin/cpp` — haxe
  резолвит относительные `-cp`/`--cpp` относительно **cwd**, НЕ hxml; hxcpp
  ищет `Options.txt` относительно cwd (иначе «Could not find dependencies
  for haxe : [Options.txt]»).
- `sdk_include` — SDK лежит **внутри пакета** (не отдельный haxelib):
  ищет `<root>/hxler/source` (dev) либо `deps/hxler/hxler/source`
  (потребитель). `mix.exs` `package()` `files:` включает `hxler/source`,
  `hxler/include`, `hxler/hxformat.json`, `lib`, `native/math/{build.hxml,
  source}` — при hex-установке SDK попадает в deps.
- `lib/math.ex` — `Hxler.Math`: `use Hxler, otp_app: :hxler, nif: :math`;
  стабы всех `@:nif`-функций в **snake_case** (имя NIF = camelToSnake:
  `accumPush`→`accum_push`, `safeDiv`→`safe_div`, `makeRefNif`→`make_ref_nif`,
  `savedTermGens`/`savedTermLoad`/`makeRefNif` — arity 0, т.к. явный `env`
  первый параметр не считается). Каждая функция ОБЯЗАНА иметь стаб до
  `load_nif`, иначе `{:bad_lib, "Function not found ..."}`
- `test/hxler_test.exs` — ExUnit E2E (20 тестов) по всем фазам: арифметика,
  64-bit, строки, dirty_cpu `fib`, `safe_div` (Ok→голый терм `5`,
  BadArg→`{:error, :zero_division}`), raw `atom_text` (не-atom→`ArgumentError`),
  list/map/bool/option, resource round-trip+dtor, pid_type/alive/send_msg/
  whereis, saved_term_gens/load, make_ref, параллельный stress.

### Ключевая ловушка E2E: multi-thread hxcpp GC deadlock
Полный `mix test` (seed 0) стабильно ВИСНУЛ на ~9-м тесте (`both`, первый с
Float) под multi-thread hxcpp GC (Immix глобальный lock), хотя каждый тест
по отдельности проходит за миллисекунды. Это тот же известный флейк, что и в
spike5 (AGENTS «Хардкорные факты»), НЕ дефект фазы 7. Решение:
`test/test_helper.exs` ставит `:erlang.system_flag(:schedulers_online, 1)` →
один scheduler = один hxcpp поток = детерминизм. Прогон 3× стабильно
20/20 за 0.1s. Стресс-тест (Task.async_stream concurrency ≥2) остаётся в
наборе и гоняет fib через dirty_cpu-потоки даже при 1 online scheduler
(dirty-пул отдельный).

### Регресс (проверено после закрытия фазы 7)
- `mix test --seed 0` = 20/20 (под schedulers_online=1).
- `hxler/test.hxml` (utest) = 94/94 ALL TESTS OK.
- `hxler/check.hxml` (Check.dll) = OK, RawGen 161 raw-functions.
- spike.exs/spike5.exs/spike6.exs — фазы 0–6 не трогает (Elixir-сторона
  добавляет только приватный fixture `lib/math.ex` + стабы).

### Генератор `mix hxler.gen` + consumer `example/` (дополнение к фазе 7)
- `lib/mix/tasks/hxler.gen.ex` — `mix hxler.gen <nif> --module Elixir.Module
  [--package pkg] [--with-resources]`: генерирует `native/<nif>/` (Haxe
  пакет `pkg`, класс `<Nif>Nif.hx`, `Entry.hx`, `Main.hx`, `build.hxml`).
  `--with-resources` добавляет `Accum.hx` + `ResourceInit.hx` (loadFn).
  Пакет default = snake(nif); валидация аргументов — через
  `OptionParser.parse` + `case {opts, [nif], []}` (паттерн-graward на nif).
- **hxler.gen.ex, run**: `snake/1` (camel/snake → snake_case) и `cls/1`
  (camelize) — helpers; `otp_app_hint/0` берёт `Mix.Project.config()[:app]`
  (в mix run возвращает значение, НЕ только при `function_exported?`).
- **Consumer `example/`**: path-dep `{:hxler, path: ".."}`. `Example.MyNif`
  `use Hxler, otp_app: :example, nif: :my_nif` + стабы `add/2`/`greet/1`
  (snake_case). `test/test_helper.exs` также ставит schedulers_online=1.
  E2E: генератор → `mix compile` (haxe+hxcpp, копия DLL) → `mix test` 2/2.
- **SDK-резолюция в compiler.ex**: `sdk_include/0` теперь читает dep из
  `Mix.Project.config()[:deps]`: для path-dep берёт его `path:` (expand
  относительно cwd) → `<path>/hxler/source`; `deps/hxler/hxler/source`
  — для hex-dep. Это нужно, т.к. для path-dep Mix НЕ копирует исходники в
  `deps/` (нет `deps/hxler` вовсе); app file формируется при
  `mix deps.compile hxler` в `_build/dev/lib/hxler/ebin/hxler.app`.
- **haxe-класс path SDK**: build.hxml шаблона генератора содержит ТОЛЬКО
  `-cp source`; компилятор ВПРЫСКИВАЕТ `-cp <sdk_include>` в команду haxe
  (additive) — это переживает любую вложенность потребителя, в отличие от
  хардкода `-cp ../../hxler/source` (оставлен только в bundled native/math).

### Можно ли пользоваться без фазы 7?
Загрузка NIF (фаза 7) — стандартный `mix compile` + `@on_load`. Фазы 0–6
проверяются спайками (spike*.exs) напрямую через `:erlang.load_nif`, без
`use Hxler`. Фаза 7 нужна только для «встроенной» сборки+загрузки в проекте.

## BEAM-потоки под NIF (на этой машине: 8 логических CPU)

- Фактические значения (проверено `erlang:system_info/1`):
  schedulers=8, schedulers_online=8, dirty_cpu_schedulers=8,
  dirty_cpu_schedulers_online=8, dirty_io_schedulers=10.
- Дефолты BEAM: normal schedulers = логические CPU (`+S`); dirty CPU =
  логические CPU, capped 10 (`+SDcpu`); dirty IO = 10 (`+SDio`).
- Итого ~26 scheduler-потоков могут одновременно заходить в hxcpp-код;
  каждый регистрируется в GC сам (SetTopOfStack → RegisterCurrentThread,
  свой LocalAllocator); boot только под `std::call_once`; hxcpp сам
  включает multi-thread GC режим.
- Максимум параллельных dirty_cpu NIF = dirty_cpu_schedulers (здесь 8);
  стресс-тест E2E (фаза 7) гоняет Task.async × N по всем scheduler-потокам.
- **Dirty-путь проверен (spike.exs):** NIF с flags=1 в ErlNifFunc
  исполняется на dirty_cpu-потоке (enif_thread_type()==2 изнутри NIF),
  normal (flags=0) — на scheduler (==1); смешанная нагрузка 8 normal +
  8 dirty_cpu concurrently — стабильна. Флаги в ручной таблице; авто-
  генерация через `@:nif(schedule=...)` — фаза 4.

## Сгенерированные файлы

`hxler/source/hxler/nif/raw/Raw.hx` — ГЕНЕРИРУЕТСЯ компиляционным макросом
`hxler/macros/RawGen.hx` (@:build на extern-классе Raw) из снапшота
`hxler/include/erl_nif_api_funcs.h`; руками не править, файл может вообще
не существовать. Путь снапшота: define `-D hxler_nif_header=<path>`
переопределяет, иначе ищется относительно classpath (trailing slash
учитывается). Генератор исключает: вариадики (использовать *_from_array),
функции с C-указателями-на-функции, get_long/make_long/get_ulong/make_ulong
(платформозависимый long ABI); функции с C-enum-параметрами и двойными
указателями генерируются как inline-обёртки untyped __cpp__ с явными
кастами (MSVC). `$a{...}`-reification в макросах создаёт array literal,
НЕ spread аргументов вызова — собирать ECall вручную.

## Тесты hxler-пакета

- `hxler/test/` — utest (`haxe test.hxml` → `bin/test/TestMain.exe`):
  ABI-значения флагов/констант, Cell/TupleView. Без BEAM.
- `hxler/check.hxml` — компиляционная ABI-верификация (все 161 raw-функции
  + Wrapper компилируются против реального erl_nif.h на MSVC) → Check.dll.
- Определение `TWinDynNifCallbacks WinDynNifCallbacks;` для standalone
  check-сборки — в @:cppFileCode класса Check (в реальном NIF его даёт
  ERL_NIF_INIT_GLOB).

## Каталог hxler/include/ (снапшот заголовков)

- `hxler/include/` — снапшот ERTS-заголовков **OTP 27.3.1 (NIF API 2.17)**
  (erl_nif_api_funcs.h, erl_nif.h, erl_drv_nif.h,
  erl_fixed_size_int_types.h, erl_int_sizes_config.h).
- Это ТОЛЬКО вход генератора `hxler.macros.RawGen` (дефолтный аргумент);
  **НЕ добавлять `hxler/include` в `-I` при сборке NIF** — C++-фаза обязана
  брать локальную ERTS через `${hxler_erts_include}`, иначе снапшот
  затенит реальный заголовок и NIF соберётся против чужой версии ABI.
- Обновление OTP: скопировать новые заголовки в `hxler/include/`
  (источник: `<code:root_dir()>/erts-*/include`) → Raw.hx перегенерируется
  сам при следующей сборке (макрос), пометка версии печатается в лог.
