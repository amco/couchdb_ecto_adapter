defmodule CouchDb.DbConnection do
  use GenServer

  def start_link(args) do
    config = build_config(args)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def info, do: GenServer.call(__MODULE__, :info)

  def insert(resource, body, options \\ []) do
    GenServer.call(__MODULE__, {:insert, resource, body, options})
  end

  def get(resource, query \\ nil, options \\ []) do
    GenServer.call(__MODULE__, {:get, resource, query, options})
  end

  def find(query, options \\ %{}) do
    GenServer.call(__MODULE__, {:_find, query, options})
  end

  def create_index(fields) do
    GenServer.call(__MODULE__, {:create_index, fields})
  end

  def handle_call(:info, _from, state) do
    response = request(:get, state[:base_url], [headers: state[:base_headers], options: state[:options]])
    {:reply, {:ok, response}, state}
  end

  def handle_call({:create_index, fields}, _from, state) do
    headers = state[:base_headers]
    url = state[:base_url] <> "/_index"

    body = %{
      index: %{
        fields: fields,
      },
      name: Enum.join(fields, "json-index"),
      type: "json"
    }

    response = request(:post, url, Jason.encode!(body), [headers: headers, options: []])
    {:reply, {:ok, response}, state}
  end

  def handle_call({:_find, query, options}, _from, state) do
    headers = state[:base_headers]
    url = state[:base_url] <> "/_find"
    body = %{selector: query}
             |> Map.merge(options)
             |> Jason.encode!

    IO.inspect body

    request(:post, url, body, [headers: headers, options: []])
    |> find_response(state)
  end

  def handle_call({:insert, resource, body, options}, _from, state) do
    headers = state[:base_headers]
    url = state[:base_url] <> "/#{resource}"
    response = request(:put, url, body, [headers: headers, options: options])
    {:reply, {:ok, response}, state}
  end

  def handle_call({:get, resource, query, options}, _from, state) do
    headers = state[:base_headers]
    query_str = build_query_str(query)
    url = "#{state[:base_url]}/#{resource}#{query_str}"
    response = request(:get, url, [headers: headers, options: options])
    {:reply, {:ok, response}, state}
  end

  def find_response(%{"warning" => warn}, state) do
    if Regex.match?(~r{^no matching index found}i, warn) do
      IO.inspect warn
      {:reply, {:error, :missing_index}, state}
    else
      {:reply, {:error, warn}, state}
    end
  end

  def find_response(response, state) do
    {:reply, {:ok, response}, state}
  end

  def request(:get, url, opts) do
    headers = opts[:headers]
    options = opts[:options] || []

    HTTPoison.get!(url, headers, options)
    |> decode_response
  end

  def request(:put, url, body, extras) do
    headers = extras[:headers]
    options = extras[:options] || []

    HTTPoison.put!(url, body, headers, options)
    |> decode_response
  end

  def request(:post, url, body, extras) do
    headers = extras[:headers]
    options = extras[:options] || []

    HTTPoison.post!(url, body, headers, options)
    |> decode_response
  end

  def build_query_str(nil), do: ""
  def build_query_str(query) when is_map(query) do
    "?#{URI.encode_query(query)}"
  end

  def build_config(args) do
    %{
      base_url: base_url(args),
      base_headers: fetch_headers(args),
      options: []
    }
  end

  defp base_url(args) do
    "#{args[:protocol]}://#{args[:hostname]}:#{args[:port]}/#{args[:database]}"
  end

  defp fetch_headers(config) do
    credentials = "#{config[:username]}:#{config[:password]}"
                    |> Base.encode64()

    [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic #{credentials}"}
    ]
  end

  defp decode_response(%{body: response}) do
    Jason.decode!(response)
  end
end
