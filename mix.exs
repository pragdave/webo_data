defmodule WeboData.MixProject do
  use Mix.Project

  def project do
    [
      app: :webo_data,
      version: "0.1.0",
      elixir: "~> 1.7-rc",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {WeboData.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      { :webo_util, path: "../webo_util" },
      { :instream,  ">= 0.0.0" },
    ]
  end
end
