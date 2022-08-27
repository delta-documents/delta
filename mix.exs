defmodule Delta.MixProject do
  use Mix.Project

  def project do
    [
      app: :delta,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :os_mon, :mnesia],
      mod: {Delta.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:benchee, "~> 1.1", only: :bench},
      {:benchee_html, "~> 1.0", only: :bench},
      {:jason, "~> 1.3"},
      {:swarm, "~> 3.4"},
      {:mongodb_driver, "~> 0.9.0"},
      {:uuid, "~> 1.1"},
    ]
  end
end
