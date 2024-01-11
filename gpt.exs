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
      system:
        """
        #{character()}
        You will be provided with a module of Elixir code, a corresponding test module and the result of running that test.
        Your task is to update the Elixir module code following its moduledocs intent so that the tests will pass and the warnings are fixed and unimplemented methods are implemented.
        Provide #{format()}
        """
        |> String.trim(),
      user:
        """
        The Elixir module:
        ```elixir
        #{module}
        ```

        The test:
        ```elixir
        #{test}
        ```

        The test output:
        ```bash
        #{error}
        ```

        Getting this right is very important to my career

        """
        |> String.trim()
    ]
    |> query(module)
  end

  def query_update_module(module_file, instruction) do
    module = File.read!(module_file)

    [
      system:
        """
        #{character()}
        You will be provided with a module of Elixir code, and an instruction to update the code.
        Your task is return the updated Elixir module according to the instruction.
        Provide #{format()}
        """
        |> String.trim(),
      user:
        """
        The Elixir module:
        ```elixir
        #{module}
        ```

        The instruction:
        #{instruction}
        """
        |> String.trim()
    ]
    |> query(module)
  end

  defp character() do
    # ""
    ""
  end

  defp format() do
    # "a minimal patch in git diff format so it can be applied with `git apply` to the provided Elixir module."
    "the full source code of the updated module and only the source code. Do not abbreviate the code using ... or similiar, but output the full module."
  end

  defp query(request, module, [model | models] \\ @default_models) do
    raw_request = [
      stream: true,
      model: model,
      messages: [
        %{role: "system", content: request[:system]},
        %{role: "user", content: request[:user]}
      ]
    ]

    new_logdir()
    write_logdir("gpt_request.json", inspect(raw_request, pretty: true, limit: :infinity))
    now = System.os_time(:millisecond)

    raw_request
    |> chat_completion()
    |> case do
      {:ok, content} ->
        write_logdir("gpt_response.json", inspect(content, pretty: true, limit: :infinity))

        case Regex.run(~r/```diff\n(.*?)```/s, content) do
          [_, diff] ->
            write_logdir("gpt_patch.diff", String.trim(diff) <> "\n")
            write_logdir("gpt_patch.ex", module)

            # unfortunately, GPT often returns wrong hunk numbers, so we're using -F10 and -c
            case System.cmd("patch", [
                   "-F10",
                   logdir("gpt_patch.ex"),
                   logdir("gpt_patch.diff")
                 ]) do
              {_, 0} ->
                {:ok, File.read!(logdir("gpt_patch.ex")), content}

              {error, _} ->
                IO.puts("GPT Patch error: #{error}")
                query(request, module, models ++ [model])
            end

          _ ->
            case Regex.run(~r/```elixir\n(.*?)```/s, content) do
              [_, code] ->
                {:ok, code <> "\n", content}

              other ->
                IO.puts(
                  "GPT Error: No code found in response #{inspect(content)} => #{inspect(other)}, retrying with model: #{model}..."
                )

                query(request, module, models ++ [model])
            end
        end

      {:error, reason} ->
        elapsed = System.os_time(:millisecond) - now
        IO.puts("GPT Error after #{elapsed / 1000}s: #{reason}, retrying with model: #{model}...")
        query(request, module, models ++ [model])
    end
  end

  defp chat_completion(request) do
    with {time, {ret, 0}} <-
           curl("https://api.openai.com/v1/chat/completions", Jason.encode!(Map.new(request))) do
      write_logdir("curl.log", ret)
      IO.puts("request #{logdir()} took #{div(time, 1000) / 1000}s")

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
      {_time, {_, code}} ->
        {:error, "Curl exit #{inspect(code)}"}
    end
  end

  defp curl(url, json) do
    :timer.tc(fn ->
      System.cmd("curl", [
        url,
        "-s",
        "-H",
        "Content-Type: application/json",
        "-H",
        "Authorization: Bearer #{System.get_env("OPENAI_API_KEY")}",
        "-d",
        json
      ])
    end)
  end

  def apply_update(module_file, code, content, extra) do
    File.write!(module_file <> ".tmp", code)

    # Logging data
    {diff, _} = System.cmd("diff", ["-u3", module_file, module_file <> ".tmp"])

    for {key, value} <- extra do
      write_logdir("extra_#{key}.log", value)
    end

    write_logdir("diff.log", diff)
    write_logdir("response.log", content)
    old_code = File.read!(module_file)
    write_logdir(Path.basename(module_file), old_code)
    write_logdir(Path.basename(module_file), code)

    # Checking file
    File.rename!(module_file <> ".tmp", module_file)
    write_logdir(Path.basename(module_file), code)

    case System.cmd("mix", ["compile", module_file], stderr_to_stdout: true) do
      {_, 0} ->
        System.cmd("mix", ["format", module_file], stderr_to_stdout: true)
        write_logdir(Path.basename(module_file), File.read!(module_file))
        :ok

      {error, _code} ->
        write_logdir("compile_error.log", error)
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
      {error, _code} ->
        write_logdir("test_error.log", error)
        {:error, error}
    end
  end

  def update_module(module_file, instruction) do
    IO.puts("Instruction: #{instruction}")
    {:ok, code, content} = query_update_module(module_file, instruction)
    apply_update(module_file, code, content, instruction: instruction)
  end

  def score(_module_file, _module_content, _test_content, _error, 0) do
    :given_up
  end

  def score(module_file, prev_module_content, test_file, error, n) do
    {:ok, module_content, debug_content} =
      query_fix_test_errors(prev_module_content, File.read!(test_file), error)

    logdir = logdir()
    IO.inspect(logdir)
    # Tests are run on disk an we need to avoid that two runs
    # update and test day1.ex at the same time
    sync(fn ->
      set_logdir(logdir)
      File.write!(module_file, prev_module_content)

      if :ok == GPT.apply_update(module_file, module_content, debug_content, prev_error: error) do
        case GPT.run_test(test_file) do
          :ok -> {:done, n}
          {:error, error} -> {:cont, error}
        end
      else
        {:done, :compile_failed}
      end
    end)
    |> case do
      {:done, ret} ->
        ret

      {:cont, error} ->
        score(module_file, module_content, test_file, error, n - 1)
    end
  end

  @logdir_key :gpt_logdir
  defp new_logdir(base \\ "gpt_log/#{System.os_time(:second)}", n \\ 0) do
    logdir = "#{base}-#{n}"

    sync(fn ->
      if File.exists?(logdir) do
        true
      else
        File.mkdir_p!(logdir)
        false
      end
    end)
    |> if do
      new_logdir(base, n + 1)
    else
      set_logdir(logdir)
    end
  end

  def set_logdir(logdir) do
    Process.put(@logdir_key, logdir)
    logdir
  end

  def write_logdir(filename, content) do
    if Process.get(@logdir_key) != nil do
      File.write!(logdir(filename), content)
    end
  end

  def logdir(filename \\ "") do
    Path.join(Process.get(@logdir_key), filename)
  end

  defp sync(fun) do
    Agent.get(:tester, fn _ -> fun.() end, :infinity)
  end
end

Agent.start_link(fn -> nil end, name: :tester)
case System.argv() do
  ["score", module, iterations, depth] ->

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
            test_file,
            error,
            depth
          )
        end,
        max_concurrency: iterations,
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
