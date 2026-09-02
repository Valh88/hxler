defmodule Hxler.Compiler do
  @moduledoc false

  # Compiles a Haxe native library (haxe -> hxcpp -> DLL/SO) and copies the
  # artifact into priv/native/<nif>.<ext>. Invoked by the `use Hxler` macro
  # at module-compile time (rustler-style); the artifact is then loaded by
  # @on_load. Skips recompilation when the artifact is newer than every
  # source (.hx) and build.hxml.

  @ext if match?({:win32, _}, :os.type()), do: ".dll", else: ".so"

  defstruct otp_app: nil, nif: nil, path: nil, external_resources: []

  # Returns a %Hxler.Compiler{} with the resolved build + copied artifact.
  def compile(otp_app, nif) do
    nif = to_string(nif)
    cwd = File.cwd!()
    native_dir = Path.join(cwd, "native")
    hxml = Path.join([native_dir, nif, "build.hxml"])

    unless File.exists?(hxml) do
      raise "Hxler: expected NIF build script #{hxml} (add #{native_dir}/#{nif}/build.hxml)"
    end

    priv = Path.join([cwd, "priv", "native"])
    File.mkdir_p!(priv)

    sources = [hxml | external_resources(native_dir, nif)]
    target = Path.join(priv, nif <> @ext)

    if stale?(target, sources) do
      Mix.shell().info("==> compiling Haxe NIF #{nif}")
      do_compile(native_dir, nif, hxml)
      copy_artifact(native_dir, nif, target)
      # Mirror priv/ into _build/<env>/lib/<otp_app> so that
      # Application.app_dir(otp_app, "priv/native/<nif>") resolves at runtime.
      Mix.Project.build_structure()
    end

    %Hxler.Compiler{
      otp_app: otp_app,
      nif: nif,
      path: "priv/native/#{nif}",
      external_resources: sources
    }
  end

  defp stale?(target, sources) do
    target_time =
      case File.stat(target, time: :posix) do
        {:ok, %{mtime: t}} -> t
        _ -> 0
      end

    newest_source =
      sources
      |> Enum.map(fn p ->
        case File.stat(p, time: :posix) do
          {:ok, %{mtime: t}} -> t
          _ -> 0
        end
      end)
      |> Enum.max(fn -> 0 end)

    target_time == 0 or newest_source > target_time
  end

  defp do_compile(native_dir, nif, hxml) do
    erts = erts_include()
    sdk_include = sdk_include()
    nif_dir = Path.join(native_dir, nif)

    # haxe resolves relative -cp/--cpp in an .hxml against the current working
    # directory (not the hxml's location), so run from inside the nif dir.
    {_, 0} =
      System.cmd(
        "haxe",
        [
          Path.basename(hxml),
          "-D",
          "hxler_erts_include=#{erts}",
          "-D",
          "hxler_sdk_include=#{sdk_include}"
        ],
        cd: nif_dir,
        stderr_to_stdout: true
      )
      |> ok!("haxe")

    build_xml = Path.join([nif_dir, "bin", "cpp", "Build.xml"])

    if File.exists?(build_xml) do
      {_, 0} =
        System.cmd(
          "haxelib",
          ["run", "hxcpp", Path.basename(build_xml), "haxe"],
          cd: Path.dirname(build_xml),
          stderr_to_stdout: true
        )
        |> ok!("haxelib run hxcpp")
    end
  end

  defp copy_artifact(native_dir, nif, target) do
    built =
      Path.wildcard(Path.join([native_dir, nif, "bin", "cpp", "*#{@ext}"]))
      |> Enum.filter(&File.regular?/1)

    if built == [] do
      raise "Hxler: no #{@ext} artifact produced for #{nif} in #{native_dir}/#{nif}/bin/cpp"
    end

    Mix.shell().info("Copying #{Path.basename(List.first(built))} to #{target}")
    File.rm(target)
    File.cp!(List.first(built), target)
  end

  defp external_resources(native_dir, nif) do
    Path.wildcard(Path.join([native_dir, nif, "source", "**", "*.hx"]))
  end

  # The Haxe SDK ships as part of the hxler package so a consumer needs no
  # separate haxelib install. Locate it in the package dir: either the
  # project itself (development: <root>/hxler/source) or the dependency
  # checkout (consumer: deps/hxler/hxler/source).
  defp sdk_include do
    cwd = File.cwd!()
    dep = Mix.Project.deps_paths()[:hxler] |> then(&if &1, do: Path.join(cwd, &1))

    candidates =
      [cwd, dep]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&Path.join([&1, "hxler", "source"]))

    case Enum.find(candidates, &File.dir?/1) do
      nil ->
        raise """
        Hxler: Haxe SDK not found. Looked in:
          #{Enum.join(candidates, "\n  ")}
        The `hxler/source` directory must be present inside the :hxler package.
        """

      path ->
        path
    end
  end

  defp erts_include do
    erts =
      Path.join(:code.root_dir(), "erts-*")
      |> Path.wildcard()
      |> List.first()

    if is_nil(erts) do
      raise "Hxler: could not locate ERTS include dir under #{:code.root_dir()}"
    end

    Path.join(erts, "include")
  end

  defp ok!({out, 0}, _what), do: {out, 0}

  defp ok!({out, code}, what) do
    raise "Hxler: `#{what}` failed (exit #{code})\n#{IO.iodata_to_binary(out)}"
  end
end
