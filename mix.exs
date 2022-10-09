defmodule Delta.MixProject do
  use Mix.Project

  def project do
    [
      app: :delta,
      name: "Delta",
      version: "0.1.0",
      source_url: "https://github.com/delta-documents/delta",
      homepage_url: "https://github.com/delta-documents",
      elixir: "~> 1.14",
      deps: deps(),
      docs: docs(),
      start_permanent: Mix.env() == :prod,
    ]
  end

  def application do
    [
      extra_applications: [:logger, :os_mon, :mnesia],
      mod: {Delta.Application, []}
    ]
  end

  def docs do
    [
      authors: ["https://github.com/florius0"],
      source_ref: System.get_env("EXDOC_SOURCE_REF") || "main",
      main: "readme",
      extras: ~w(README.md),
      formatters: ["html"],
      javascript_config_path: "../.doc-versions.js"
    ]
  end

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
