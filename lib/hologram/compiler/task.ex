# DEFER: refactor & test

defmodule Mix.Tasks.Compile.Hologram do
  use Mix.Task.Compiler
  require Logger

  alias Hologram.Compiler.{Builder, IRStore, Reflection}
  alias Hologram.{MixProject, Utils}

  @root_path Reflection.root_path()

  def run(opts \\ []) do
    logger_config = Application.fetch_env!(:logger, :console)
    Logger.configure_backend(:console, logger_config)
    Logger.debug("Hologram compiler started")

    IRStore.create()

    output_path = resolve_output_path()

    File.mkdir_p!(output_path)
    remove_old_files(output_path)

    build_runtime()

    digests =
      Reflection.list_pages(opts)
      |> Enum.map(&(Task.async(fn -> build_page(&1, output_path) end)))
      |> Utils.await_tasks()

    build_manifest(digests, output_path)
    reload_routes()

    IRStore.destroy()

    Logger.debug("Hologram compiler finished")

    :ok
  end

  defp build_manifest(digests, output_path) do
    json =
      Enum.into(digests, %{})
      |> Jason.encode!()

    "#{output_path}/manifest.json"
    |> File.write!(json)
  end

  defp build_page(page, output_path) do
    js = Builder.build(page)
    output = "\"use strict\";\n\n" <> js

    digest =
      :crypto.hash(:md5, output)
      |> Base.encode16()
      |> String.downcase()

    "#{output_path}/page-#{digest}.js"
    |> File.write!(output)

    {page, digest}
  end

  defp build_runtime do
    assets_path =
      if MixProject.is_dep?() do
        "deps/hologram/assets"
      else
        "assets"
      end

    System.cmd("npm", ["install"], cd: assets_path)
    Mix.Task.run("esbuild", ["hologram", "--log-level=warning"])
  end

  # Routes are defined in page modules and the router aggregates the routes dynamically by reflection.
  # So everytime a route is updated in a page module, we need to explicitely recompile the router module, so that
  # it rebuilds the list of routes.
  defp reload_routes do
    router_path = Reflection.router_path()

    opts = Code.compiler_options()
    Code.compiler_options(ignore_module_conflict: true)
    Code.compile_file(router_path)
    Code.compiler_options(ignore_module_conflict: opts.ignore_module_conflict)
  end

  defp remove_old_files(output_path) do
    "#{output_path}/*"
    |> Path.wildcard()
    |> Enum.each(&File.rm!/1)
  end

  defp resolve_output_path do
    if MixProject.is_dep?() do
      "#{@root_path}/../../priv/static/hologram"
    else
      "#{@root_path}/priv/static/hologram"
    end
  end
end
