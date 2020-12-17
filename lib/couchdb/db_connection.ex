defmodule Couchdb.DbConnection do
#  use GenServer
#
#  def start_link(args) do
#    GenServer.start_link(__MODULE__, args, name: __MODULE__)
#  end
#
#  def init(args) do
#    IO.inspect args
#    {:ok, args}
#  end
#
#  def handle_call(:info, _from, state) do
#    response = request(:get, state[:url], [headers: state[:headers], options: state[:options]])
#    {:reply, {:ok, response}, state}
#  end
#
#  def request(:get, url, opts) do
#    headers = opts[:headers]
#    options = opts[:options] || []
#
#    HTTPoison.get!(url, headers, options)
#  end
end
