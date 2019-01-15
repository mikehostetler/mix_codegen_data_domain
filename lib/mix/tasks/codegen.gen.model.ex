defmodule Mix.Tasks.Codegen.Gen.Model do
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator
  import Path

  @shortdoc "Mix Codegen compliant task to generate a new model"

  def run(args) do
    {_opts, [app_name, resource, plural_name | inputs], _} =
      OptionParser.parse(args, switches: [])

    resource_list = String.split(resource, "/")
    [context, singular_name] = Enum.take(resource_list, -2)

    inputs =
      inputs
      |> parse_inputs()
      |> generate_schema_types()

    generate_model(app_name, context, singular_name, plural_name, inputs)
    # generate_migration(app_name, context, singular_name, plural_name, inputs)
    # generate_model_test(app_name, context, singular_name, plural_name, inputs)
  end

  defp generate_model(app_name, context, singular_name, plural_name, inputs) do
    contexts = [
      app_name: camelize(app_name),
      mod: camelize(singular_name),
      context: camelize(context),
      plural_name: underscore(plural_name),
      fields: inputs.fields,
      assocs: inputs.assocs
    ]

    path = "lib/#{underscore(app_name)}/data/model/#{underscore(singular_name)}.ex"
    create_file(path, model_template(contexts))

    path = "lib/#{underscore(app_name)}/data/model/gen/#{underscore(singular_name)}.ex"
    create_file(path, model_codegen_template(contexts))
  end

  defp generate_migration(app_name, context, singular_name, plural_name, inputs) do
    path = "priv/repo/migrations/"
    base_name = "#{timestamp()}_create_#{underscore(plural_name)}_table.exs"
    file = Path.join(path, base_name)

    create_directory(path)

    contexts = [
      app_name: camelize(app_name),
      mod: camelize(singular_name),
      context: camelize(context),
      plural_name: underscore(plural_name),
      fields: inputs.fields,
      assocs: inputs.assocs
    ]

    create_file(file, migration_template(contexts))
  end

  defp generate_model_test(app_name, context, singular_name, plural_name, inputs) do
    path = "test/data/model"
    base_name = "#{underscore(singular_name)}_test.exs"
    file = Path.join(path, base_name)

    create_directory(path)

    contexts = [
      app_name: camelize(app_name),
      mod: camelize(singular_name),
      context: camelize(context),
      plural_name: underscore(plural_name),
      fields: inputs.fields,
      assocs: inputs.assocs
    ]

    create_file(file, model_test_template(contexts))
  end

  # Templates

  try do
    embed_template(:model,
      from_file: Path.expand("#{__DIR__}/../../../priv/codegen/model_template.eex")
    )
  rescue
    _ ->
      embed_template(:model, """
      defmodule <%= @app_name %>.Data.Model.<%= @mod %> do
        use <%= @app_name %>.Model

        alias Ecto.Multi
        alias <%= @app_name %>.Data.Schema.<%= @mod %>

        schema "<%= @plural_name %>" do
        <%= for {field, type} <- @fields do %>
          field :<%= field %>, <%= type %><% end %>
        <%= for {field, _type, schema} <- @assocs do %>
          belongs_to :<%= field %>, <%= schema %><% end %>
          timestamps()
        end
      end
      """)
  end

  try do
    embed_template(:model_base,
      from_file: Path.expand("#{__DIR__}/../../../priv/codegen/model_base_template.eex")
    )
  rescue
    _ ->
      embed_template(:model, """
      defmodule <%= @app_name %>.Data.Model.<%= @mod %> do
        use <%= @app_name %>.Model

        alias Ecto.Multi
        alias <%= @app_name %>.Data.Schema.<%= @mod %>

        schema "<%= @plural_name %>" do
        <%= for {field, type} <- @fields do %>
          field :<%= field %>, <%= type %><% end %>
        <%= for {field, _type, schema} <- @assocs do %>
          belongs_to :<%= field %>, <%= schema %><% end %>
          timestamps()
        end
      end
      """)
  end

  try do
    embed_template(:migration,
      from_file: Path.expand("#{__DIR__}/../../../priv/codegen/migration_template.eex")
    )
  rescue
    _ ->
      embed_template(:migration, """
      defmodule <%= @app_name %>.Repo.Migrations.Create<%= @mod %> do
        use Ecto.Migration

        def change do
          create table(:<%= @plural_name %>) do
      <%= for {field, type} <- @fields do %>
          add :<%= field %>, <%= type %><% end %>
      <%= for {field, _type, _} <- @assocs do %>
          add :<%= field %>_id, references(:<%= @plural_name %>)<% end %>
          timestamps()
        end
      end
      """)
  end

  try do
    embed_template(:model_test,
      from_file: Path.expand("#{__DIR__}/../../../priv/codegen/model_test_template.eex")
    )
  rescue
    _ ->
      embed_template(:model_test, """
      defmodule <%= @app_name %>.<%= @context %>.<%= @mod %>Test do
        use <%= @app_name %>.DataCase
        # alias <%= @app_name %>.<%= @context %>.<%= @mod %>

        test "example" do
          assert true
        end
      end
      """)
  end

  defp parse_inputs(raw_inputs) do
    raw_inputs
    |> Enum.filter(&String.contains?(&1, ":"))
    |> Enum.map(fn raw_input ->
      case String.split(raw_input, ":") do
        [key, type] ->
          {key, String.to_atom(type)}

        [key, type, schema_or_type] ->
          {key, String.to_atom(type), String.to_atom(schema_or_type)}

        [key] ->
          {key, :string}
      end
    end)
  end

  defp generate_schema_types(inputs) do
    Enum.reduce(inputs, %{fields: [], assocs: []}, fn
      {key, :references}, acc ->
        Map.put(acc, :assocs, acc.assocs ++ [{key, :references, camelize(key)}])

      {key, :array, type}, acc ->
        Map.put(acc, :fields, acc.fields ++ [{key, "{:array, #{type}}"}])

      {key, type}, acc ->
        Map.put(acc, :fields, acc.fields ++ [{key, ":#{type}"}])
    end)
  end

  # https://github.com/phoenixframework/phoenix/blob/3318efe41ffc629455f1509d2e545f55a2ea218d/lib/mix/tasks/phx.gen.schema.ex#L203
  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
