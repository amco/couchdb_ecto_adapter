defmodule User do
  use Ecto.Schema

  @primary_key {:_id, :binary_id, autogenerate: true}
  schema "users" do
    field :_rev
    field :first_name
    field :last_name
    field :username
    field :email
  end
end
