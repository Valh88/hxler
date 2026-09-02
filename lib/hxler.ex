defmodule Hxler do
  @moduledoc """
  Compile-time configuration and runtime loading of a Haxe NIF module.

  When used, `Hxler` expects the `:otp_app` option pointing at the OTP
  application that owns the compiled NIF artifacts (the **consumer's** app,
  not necessarily `:hxler`):

      defmodule MyNIF do
        use Hxler, otp_app: :my_app
      end

  The NIF is compiled at module-compile time from `native/<nif>/build.hxml`
  in the consumer project (see `Hxler.Compiler`), the resulting DLL/SO is
  copied into the owning app's `priv/native`, and a `@on_load` callback
  loads it at runtime.

  ## Configuration

  The following are read from `config/config.exs` under the owning app, or
  passed directly to `use`:

    * `:nif` - name of the native library under `native/`. Defaults to the
      `:otp_app` value.

  Any option given to `use` overrides the app configuration.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      otp_app = Keyword.fetch!(opts, :otp_app)

      config =
        otp_app
        |> Application.compile_env(__MODULE__, [])
        |> then(&Keyword.merge(opts, &1))

      nif = Keyword.get(config, :nif, otp_app)
      build = Hxler.Compiler.compile(otp_app, nif)

      for resource <- build.external_resources do
        @external_resource resource
      end

      @hxler_otp_app otp_app
      @hxler_load_from build.path
      @before_compile Hxler
    end
  end

  defmacro __before_compile__(env) do
    otp_app = Module.get_attribute(env.module, :hxler_otp_app)
    load_from = Module.get_attribute(env.module, :hxler_load_from)

    quote do
      @on_load :hxler_init

      @doc false
      def hxler_init do
        :code.purge(__MODULE__)

        load_path =
          unquote(otp_app)
          |> Application.app_dir(unquote(load_from))
          |> to_charlist()

        :erlang.load_nif(load_path, 0)
      end
    end
  end
end
