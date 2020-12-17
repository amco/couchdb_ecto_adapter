defmodule SisWeb.PageController do
  use SisWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
