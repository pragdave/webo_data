defmodule WeboData.Application do
  use Application

  def start(_type, _args) do
    children = [
      Webo.Data.InfluxConnection,
    ]

    opts = [strategy: :one_for_one, name: WeboData.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
