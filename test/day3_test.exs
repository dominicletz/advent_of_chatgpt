defmodule Day3Test do
  use ExUnit.Case

  test "check day 3" do
    assert Day3.evaluate("""
           467..114..
           ...*......
           ..35..633.
           ......#...
           617*......
           .....+.58.
           ..592.....
           ......755.
           ...$.*....
           .664.598..
           """) == 4361
  end
end
