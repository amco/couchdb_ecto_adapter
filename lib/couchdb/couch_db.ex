defmodule CouchDb.Adapter do
  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Schema

  defmacro __before_compile__(_env), do: :ok

  def init(config) do
    log = Keyword.get(config, :log, :debug)
    telemetry_prefix = Keyword.fetch!(config, :telemetry_prefix)
    telemetry = {config[:repo], log, telemetry_prefix ++ [:query]}
    {:ok, child_spec(config), %{ telemetry: telemetry, opts: [returning: true] }}
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

  def insert(meta, _repo, fields, _on_conflict, returning, _options) do
    data = Enum.into(fields, %{})
    id = "user/#{Map.get(data, :_id)}"
    data = Map.put(data, :_id, id)

    body = Jason.encode!(data)
    url = full_url(meta[:config], data)
    headers = fetch_headers(meta[:config])

    response = request(:put, url, body, [headers: headers])
    response = Jason.decode! response.body
    response = Map.merge(data, %{_id: response["id"], _rev: response["rev"]})

    values = Enum.map(returning, fn(k)-> Map.get(response, k) end)

    {:ok, Enum.zip(returning, values)}
  end

  def full_url(config, %{_id: resource_id}) do
    "#{config[:protocol]}://#{config[:hostname]}:#{config[:port]}/#{config[:database]}/#{:http_uri.encode(resource_id)}"
  end

  def delete(_a, _b, _c, _d) do
  end

  def insert_all(_a, _b, _c, _d, _e, _f, _g) do
  end

  def update(_a, _b_, _c, _d, _e_, _f) do
  end

  def fetch_headers(config) do
    credentials = "#{config[:username]}:#{config[:password]}"
                    |> Base.encode64()

    [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic #{credentials}"}
    ]
  end

  def request(:put, url, body, extras) do
    headers = extras[:headers]
    options = extras[:options] || []

    HTTPoison.put!(url, body, headers, options)
  end

  def request(:get, url, opts) do
    headers = opts[:headers]
    options = opts[:options] || []

    HTTPoison.get!(url, headers, options)
  end
end
