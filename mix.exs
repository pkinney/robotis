defmodule Robotis.MixProject do
  use Mix.Project

  def project do
    [
      app: :robotis,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_uart, "~> 1.0"},
      # {:mimic, "~> 1.7", only: :test},
      {:resolve, "~> 0.1"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:replay, path: "../replay", only: :test}
    ]
  end
end
