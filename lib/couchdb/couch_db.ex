defmodule CouchDb.Adapter do
  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Schema
  @behaviour Ecto.Adapter.Queryable

  @conn CouchDb.DbConnection

  @query_map [
    ==: "$eq",
    or: "$or",
    and: "$and"
  ]

  defmacro __before_compile__(_env), do: :ok

  def init(config) do
    log = Keyword.get(config, :log, :debug)
    telemetry_prefix = Keyword.fetch!(config, :telemetry_prefix)
    telemetry = {config[:repo], log, telemetry_prefix ++ [:query]}

    opts = [strategy: :one_for_one, name: CouchDb.DbConnection.Supervisor]
    Supervisor.start_link([{CouchDb.DbConnection, config}], opts)

    {:ok, child_spec(config), %{ telemetry: telemetry, opts: [returning: true], config: config }}
  end

  def ensure_all_started(_repo, _type), do: HTTPoison.start
  def checkout(_adapter, _config, result) do
    result
  end

  def dumpers({:map, _}, type), do: [&Ecto.Type.embedded_dump(type, &1, :json)]
  def dumpers(_primitive, type), do: [type]

  def loaders({:map, _}, type), do: [&Ecto.Type.embedded_load(type, &1, :json)]
  def loaders(_primitive, type), do: [type]

  def child_spec(_), do: Supervisor.Spec.supervisor(Supervisor, [[], [strategy: :one_for_one]])

  def autogenerate(:id), do: nil
  def autogenerate(:binary_id) do
    Ecto.UUID.cast!(Ecto.UUID.bingenerate)
  end

  def prepare(:all, query) do
    %{wheres: wheres} = query
    keys = Enum.map(wheres, &parse_where/1)
    {:nocache, {System.unique_integer([:positive]), keys}}
  end

  def parse_where([]), do: []
  def parse_where(%Ecto.Query.BooleanExpr{expr: expr}) do
    {condition, _, fields} = expr
    build_query_condition(condition, fields)
  end

  def build_query_condition(_, [{{_, [], [{_, [], [_]}, key]}, [], []}, value]) do
    %{ key => value }
  end

  def build_query_condition(condition, fields) do
    %{
       @query_map[condition] => build_query(fields)
     }
  end

  def build_query(fields) do
    Enum.map(fields, &build_field_condition/1)
  end

  def build_field_condition({:^, [], [0]}), do: :primary_key
  def build_field_condition({{_, _, [{_, _, [0]}, key]}, _, _}), do: %{key => :empty}
  def build_field_condition({expr, _, [{{_, _, [_, key]}, _, _}, value]}) do
    %{
       key => %{ @query_map[expr] => value }
     }
  end

  def execute(meta, query_meta, query_cache, params, opts) do
    {_, {_, keys}}        = query_cache
    %{select: select}     = query_meta
    {all_fields, module}  = fetch_fields(query_meta.sources)
    namespace             = build_namespace(module)

    fields = case select.postprocess do
      {:map, keyfields} ->
        Keyword.keys(keyfields)
        |> Enum.map(&Atom.to_string/1)
      _-> all_fields
    end

    IO.inspect fields

    case do_query(keys, namespace, params) do
      [error: :missing_index] ->
        # Will create the index
        Enum.flat_map(keys, fn(key)->
          [{_, keymaps}] = Map.to_list(key)
          Enum.flat_map keymaps, &Map.keys/1
        end)
        |> @conn.create_index
        execute(meta, query_meta, query_cache, params, opts)
      {:ok, response} ->
        [Enum.map(fields, fn(field)-> Map.get(response, field) end)]
        |> execute_response
      [ok: response]->
        IO.inspect response

        response
        |> Map.get("docs")
        |> Enum.map(fn(doc) ->
             Enum.map(fields, fn(field)-> Map.get(doc, field) end)
           end)
        |> execute_response
    end
  end

  def execute_response(values) when is_list(values), do: {length(values), values}
  def fetch_fields({{resource, nil, _}}) do
    module = ["Elixir", ".", resource]
               |> Enum.map(&Inflex.singularize/1)
               |> Enum.map(&String.capitalize/1)
               |> Enum.join
               |> String.to_existing_atom

    fetch_fields({{resource, module, nil}})
  end

  def fetch_fields({{_resource, module, _}}) do
    fields = module.__struct__
               |> Map.keys
               |> Kernel.--([:__struct__, :__meta__])
               |> Enum.map(&Atom.to_string/1)

    {fields, module}
  end

  def do_query([%{"$eq" => [%{_id: :empty}, :primary_key]}], namespace, [id | _]) do
    @conn.get(namespace_id(namespace, id))
  end

  def do_query(queries, _namespace, _params) do
    Enum.map(queries, &@conn.find/1)
  end

  def build_namespace(module) do
    module
      |> to_string
      |> String.split(".")
      |> List.last
      |> String.downcase
  end

  def namespace_id(namespace, id) do
    if Regex.match?(~r{^#{namespace}/}, id) do
      id
    else
      namespace
        |> Kernel.<>("/#{id}")
        |> :http_uri.encode
    end
  end

  def insert(_meta, repo, fields, _on_conflict, returning, _options) do
    data = Enum.into(fields, %{})
           |> build_id(repo)

    url  = :http_uri.encode(data._id)
    body = Jason.encode!(data)

    {:ok, response} = @conn.insert(url, body)
    response = Map.merge(data, %{_id: response["id"], _rev: response["rev"]})
    values = Enum.map(returning, fn(k)-> Map.get(response, k) end)

    {:ok, Enum.zip(returning, values)}
  end

  def fetch_doc_type({resource, nil}) do
    Inflex.singularize(resource)
  end

  def fetch_doc_type({_, resource}) do
    resource
      |> to_string
      |> String.split(".")
      |> List.last
      |> String.downcase
  end

  def build_id(data, %{schema: resource}) do
    resource
      |> to_string
      |> String.split(".")
      |> List.last
      |> String.downcase
      |> Kernel.<>("/#{data._id}")
      |> update_data_id(data)
  end

  def update_data_id(id, data) do
    Map.put(data, :_id, id)
  end

  def delete(_a, _b, _c, _d) do
  end

  def insert_all(_a, _b, _c, _d, _e, _f, _g) do
  end

  def update(_a, _b_, _c, _d, _e_, _f) do
  end

  def request(:get, url, opts) do
    headers = opts[:headers]
    options = opts[:options] || []

    HTTPoison.get!(url, headers, options)
  end
end
