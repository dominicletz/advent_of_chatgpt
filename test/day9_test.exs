defmodule Day9Test do
  use ExUnit.Case

  test "check day 9" do
    assert Day9.evaluate("""
           0 3 6 9 12 15
           1 3 6 10 15 21
           10 13 16 21 30 45
           """) == 114
  end
end
