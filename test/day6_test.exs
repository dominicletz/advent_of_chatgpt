defmodule Day6Test do
  use ExUnit.Case

  test "check day 6" do
    assert Day6.evaluate("""
           Time:      7  15   30
           Distance:  9  40  200
           """) == 288
  end
end
