#!/bin/env elixir
Mix.install([:jason])

defmodule GPT do
  @default_models [
    "gpt-4-1106-preview",
    "gpt-4-1106-preview",
    "gpt-4-1106-preview",
    "gpt-3.5-turbo-16k"
  ]

  def query_fix_test_errors(module_file, test_file, error) do
    module = File.read!(module_file)
    test = File.read!(test_file)

    [
      system: """
      You will be provided with a module of Elixir code, a corresponding test module and the result of running that test.
      Your task is return the updated Elixir module code following its moduledocs intent so that the tests will pass and the warnings are
      fixed and unimplemented methods are implemented.
      Provide the full source code of the module and only the source code. Do not abbreviate the code use ... or similiar, but output the full module.
      """,
      user:
        "The Elixir module:\n```elixir\n#{module}\n```\n\nThe test:\n```elixir\n#{test}\n```\n\nThe test output:\n```bash\n#{error}\n```"
    ]
    |> query()
  end

  def query_update_module(module_file, instruction) do
    module = File.read!(module_file)

    [
      system: """
      You will be provided with a module of Elixir code, and an instruction to update the code.
      Your task is return the updated Elixir module according to the instruction.
      Provide the full source code of the updated module and only the source code. Do not abbreviate the code use ... or similiar, but output the full module.
      """,
      user: "The Elixir module:\n```elixir\n#{module}\n```\n\nThe instruction:\n#{instruction}"
    ]
    |> query()
  end

  defp query(request, [model | models] \\ @default_models) do
    raw_request = [
      stream: true,
      model: model,
      messages: [
        %{role: "system", content: request[:system]},
        %{role: "user", content: request[:user]}
      ]
    ]

    File.write!("gpt_request.json", inspect(raw_request, pretty: true, limit: :infinity))
    now = System.os_time(:millisecond)

    raw_request
    |> chat_completion()
    |> case do
      {:ok, content} ->
        case Regex.run(~r/```elixir\n(.*)\n```/s, content) do
          [_, code] ->
            {:ok, code <> "\n", content}

          other ->
            IO.puts(
              "GPT Error: No code found in response #{inspect(content)} => #{inspect(other)}, retrying with model: #{model}..."
            )

            query(request, models ++ [model])
        end

      {:error, reason} ->
        elapsed = System.os_time(:millisecond) - now
        IO.puts("GPT Error after #{elapsed / 1000}s: #{reason}, retrying with model: #{model}...")
        query(request, models ++ [model])
    end
  end

  defp chat_completion(request) do
    with {ret, 0} <-
           System.cmd("curl", [
             "https://api.openai.com/v1/chat/completions",
             "-H",
             "Content-Type: application/json",
             "-H",
             "Authorization: Bearer #{System.get_env("OPENAI_API_KEY")}",
             "-d",
             Jason.encode!(Map.new(request))
           ]) do
      File.write!("curl.log", ret)

      ret =
        String.split(ret, "\n\n", trim: true)
        |> Enum.map(fn
          "data: [DONE]" ->
            ""

          "data: " <> ret ->
            with {:ok, data} <- Jason.decode(ret) do
              case hd(data["choices"]) do
                %{"delta" => %{"content" => content}} -> content
                %{"finish_reason" => "stop"} -> ""
              end
            else
              other -> raise "Error: #{inspect(other)}"
            end
        end)
        |> Enum.join("")

      {:ok, ret}
    else
      {_, code} ->
        {:error, "Curl exit #{code}"}
    end
  end

  def apply_update(module_file, code, content, extra) do
    File.write!(module_file <> ".tmp", code)

    # Logging data
    {diff, _} = System.cmd("diff", ["-u3", module_file, module_file <> ".tmp"])
    logdir = "gpt_log/#{System.system_time(:seconds)}/"
    File.mkdir_p!(logdir)

    for {key, value} <- extra do
      File.write!("#{logdir}#{key}.log", value)
    end

    File.write!("#{logdir}diff.log", diff)
    File.write!("#{logdir}response.log", content)
    old_code = File.read!(module_file)
    File.write!("#{logdir}#{Path.basename(module_file)}", old_code)
    File.write!("#{logdir}#{Path.basename(module_file)}.new", code)

    # Reporting diff
    # IO.puts(diff)

    # Checking file
    File.rename!(module_file <> ".tmp", module_file)

    case System.cmd("mix", ["compile", module_file]) do
      {_, 0} ->
        System.cmd("mix", ["format", module_file])
        :ok

      {error, _code} ->
        IO.puts("Compile error - reverting file: \n#{error}")
        File.write!(module_file, old_code)
        {:error, error}
    end
  end

  def improve_module(test_file, module_file) do
    with {:error, error} <- run_test(test_file) do
      IO.puts("Error is:\n#{error}")
      {:ok, code, content} = query_fix_test_errors(module_file, test_file, error)
      apply_update(module_file, code, content, error: error)
    end
  end

  def run_test(test_file) do
    case System.cmd("mix", ["test", test_file], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _code} -> {:error, error}
    end
  end

  def update_module(module_file, instruction) do
    IO.puts("Instruction: #{instruction}")
    {:ok, code, content} = query_update_module(module_file, instruction)
    apply_update(module_file, code, content, instruction: instruction)
  end
end

case System.argv() do
  ["score", module, iterations] ->
    test_file = "test/#{module}_test.exs"
    module_file = "lib/#{module}.ex"
    iterations = String.to_integer(iterations)
    module_content = File.read!(module_file)
    {:error, error} = GPT.run_test(test_file)

    score =
      1..iterations
      |> Task.async_stream(
        fn _i ->
          {:ok, _code, _content} = GPT.query_fix_test_errors(module_file, test_file, error)
        end,
        timeout: :infinity
      )
      |> Enum.to_list()
      |> Enum.reduce({0, 0, 0}, fn {:ok, {:ok, code, content}}, {test_ok, compile_ok, not_ok} ->
        File.write!(module_file, module_content)

        case GPT.apply_update(module_file, code, content, error: error) do
          :ok ->
            case GPT.run_test(test_file) do
              :ok -> {test_ok + 1, compile_ok, not_ok}
              _ -> {test_ok, compile_ok + 1, not_ok}
            end

          _ ->
            {test_ok, compile_ok, not_ok + 1}
        end
      end)

    File.write!(module_file, module_content)
    IO.puts("#{module} score: #{inspect score}/#{iterations}")

  ["test", module, iterations] ->
    test_file = "test/#{module}_test.exs"
    module_file = "lib/#{module}.ex"
    iterations = String.to_integer(iterations)

    for x <- 1..iterations do
      IO.puts("Iteration #{x}")

      if :ok == GPT.improve_module(test_file, module_file) do
        System.halt(0)
      end
    end

  ["update", module | instruction] ->
    module_file = "lib/#{module}.ex"
    GPT.update_module(module_file, Enum.join(instruction, " "))

  _other ->
    IO.puts("""
      SYNTAX:

      gpt test <module_name> <number of iterations>
      gpt update <module_name> <instructions>
    """)
end
