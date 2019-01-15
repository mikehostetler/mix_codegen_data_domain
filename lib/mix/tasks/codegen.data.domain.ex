defmodule Mix.Tasks.Codegen.Data.Domain do
  @moduledoc """
  Mix Codegen compliant Mix Tasks to generate a full Data Domain
  for a given Schema, with tests and migrations.

  The repository must be set under `:ecto_repos` in the
  current app configuration or given via the `-r` option.

  ## Examples

      mix ecto.gen.migration add_posts_table
      mix ecto.gen.migration add_posts_table -r Custom.Repo

  The generated migration filename will be prefixed with the current
  timestamp in UTC which is used for versioning and ordering.

  By default, the migration will be generated to the
  "priv/YOUR_REPO/migrations" directory of the current application
  but it can be configured to be any subdirectory of `priv` by
  specifying the `:priv` key under the repository configuration.

  This generator will automatically open the generated file if
  you have `ECTO_EDITOR` set in your environment variable.

  ## Command line options

    * `-r`, `--repo` - the repo to generate migration for
    * `--no-compile` - does not compile applications before running
    * `--no-deps-check` - does not check depedendencies before running

  """
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator
  import Mix.Ecto
  import Mix.EctoSQL

  @shortdoc "Mix Codegen compliant task to generate a new migration for the repo"

  @aliases [
    r: :repo
  ]

  @switches [
    change: :string,
    timestamp: :string,
    repo: [:string, :keep],
    no_compile: :boolean,
    no_deps_check: :boolean
  ]

  @doc """
  Accepts a map of parameters from config file intended to run this task.

  This function serves as a place for the task author to convert the configuration map
  into acceptable arguments to invoke the `run/1` function in this Task.
  """
  def run_codegen(config) do
    repo = if config["repo"], do: ["--repo", config["repo"]], else: []
    timestamp = if config["timestamp"], do: ["--timestamp", config["timestamp"]], else: []
    name = if config["name"], do: [config["name"]], else: []

    run(repo ++ timestamp ++ name)
  end

  @impl true
  def run(args) do
    # ./apps/mw/lib/mw/data/model/route.ex
    # ./apps/mw/test/data/model/route_test.exs

    # ./apps/mw/priv/repo/migrations/20181021153457_add_route_table.exs
    # ./apps/mw/priv/repo/seed/route.ex

    # ./apps/mw/lib/mw/data/schema/route.ex
    # ./apps/mw/test/data/schema/route_test.exs
  end

  defp timestamp(nil) do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp timestamp(timestamp_prefix) do
    timestamp_prefix
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  embed_template(:migration, """
  defmodule <%= inspect @mod %> do
    use Ecto.Migration
    def change do
  <%= @change %>
    end
  end
  """)
end
