defmodule AdventOfCode2023.MixProject do
  use Mix.Project

  def project do
    [
      app: :advent_of_code_2023,
      version: "0.1.0",
      elixir: "~> 1.10"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
