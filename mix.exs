defmodule Jop.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jop,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end
end
