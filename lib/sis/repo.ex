defmodule Sis.Repo do
  use Ecto.Repo,
    otp_app: :sis,
    adapter: CouchDb.Adapter

  def default_options(_), do: [returning: true]
end
