defmodule Day20Test do
  use ExUnit.Case

  test "check day 20" do
    assert Day20.evaluate("""
           broadcaster -> a, b, c
           %a -> b
           %b -> c
           %c -> inv
           &inv -> a
           """) == 32_000_000

    assert Day20.evaluate("""
           broadcaster -> a
           %a -> inv, con
           &inv -> b
           %b -> con
           &con -> output
           """) == 11_687_500
  end
end
