#!/bin/env elixir
Mix.install([:jason])

defmodule GPT do
  @default_models [
    "gpt-4-1106-preview",
    "gpt-4-1106-preview",
    "gpt-4-1106-preview",
    "gpt-3.5-turbo-16k"
  ]

  def query_fix_test_errors(module, test, error) do
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

  defp new_logdir(base, n) do
    logdir = "#{base}-#{n}"

    if File.exists?(logdir) do
      new_logdir(logdir, n + 1)
    else
      File.mkdir_p!(logdir)
      logdir
    end
  end

  def apply_update(module_file, code, content, extra) do
    File.write!(module_file <> ".tmp", code)

    # Logging data
    {diff, _} = System.cmd("diff", ["-u3", module_file, module_file <> ".tmp"])
    logdir = new_logdir("gpt_log/#{System.system_time(:second)}", 0) <> "/"

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

    case System.cmd("mix", ["compile", module_file], stderr_to_stdout: true) do
      {_, 0} ->
        System.cmd("mix", ["format", module_file], stderr_to_stdout: true)
        :ok

      {error, _code} ->
        IO.puts("Compile error - reverting file: \n#{error}")
        File.write!(module_file, old_code)
        {:error, error}
    end
  end

  def improve_module(test_file, module_file, error) do
    IO.puts("Error is:\n#{error}")

    {:ok, code, content} =
      query_fix_test_errors(File.read!(module_file), File.read!(test_file), error)

    apply_update(module_file, code, content, prev_error: error)
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

  def score(_module_file, _original_module_content, _module_content, _test_content, _error, 0) do
    :given_up
  end

  def score(module_file, prev_module_content, test_file, error, n) do
    {:ok, module_content, debug_content} =
      GPT.query_fix_test_errors(prev_module_content, File.read!(test_file), error)

    # Tests are run on disk an we need to avoid that two runs
    # update and test day1.ex at the same time
    Agent.get(
      :tester,
      fn nil ->
        File.write!(module_file, prev_module_content)

        if :ok == GPT.apply_update(module_file, module_content, debug_content, prev_error: error) do
          case GPT.run_test(test_file) do
            :ok -> {:done, n}
            {:error, error} -> {:cont, error}
          end
        else
          {:done, :compile_failed}
        end
      end,
      :infinity
    )
    |> case do
      {:done, ret} ->
        ret

      {:cont, error} ->
        score(module_file, module_content, test_file, error, n - 1)
    end
  end
end

case System.argv() do
  ["score", module, iterations, depth] ->
    Agent.start_link(fn -> nil end, name: :tester)

    test_file = "test/#{module}_test.exs"
    module_file = "lib/#{module}.ex"
    original_module_content = File.read!(module_file)

    iterations = String.to_integer(iterations)
    depth = String.to_integer(depth)
    {:error, error} = GPT.run_test(test_file)

    score =
      1..iterations
      |> Task.async_stream(
        fn _i ->
          GPT.score(
            module_file,
            original_module_content,
            original_module_content,
            test_file,
            error,
            depth
          )
        end,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.reduce(%{}, fn {:ok, ret}, map ->
        Map.put(map, ret, Map.get(map, ret, 0) + 1)
      end)

    File.write!(module_file, original_module_content)
    keys = Enum.to_list(depth..1) ++ [:given_up, :compile_failed]
    score = Enum.map(keys, fn x -> Map.get(score, x, 0) end)
    result = "#{module} score: #{inspect(score)} / #{iterations}"

    File.write!("score.txt", "#{result}\n", [:append])
    IO.puts("#{result}")

  ["test", module, iterations] ->
    test_file = "test/#{module}_test.exs"
    module_file = "lib/#{module}.ex"
    iterations = String.to_integer(iterations)

    for x <- 1..iterations do
      IO.puts("Iteration #{x}")

      case GPT.run_test(test_file) do
        :ok ->
          IO.puts("Tests pass!")
          System.halt(0)

        {:error, error} ->
          GPT.improve_module(test_file, module_file, error)
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
