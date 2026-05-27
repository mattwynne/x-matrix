defmodule XMatrix.Repo do
  use Ecto.Repo,
    otp_app: :x_matrix,
    adapter: Ecto.Adapters.Postgres
end
