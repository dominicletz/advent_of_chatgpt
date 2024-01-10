defmodule Day21Test do
  use ExUnit.Case

  test "check day 21" do
    assert Day21.evaluate("""
           ...........
           .....###.#.
           .###.##..#.
           ..#.#...#..
           ....#.#....
           .##..S####.
           .##..#...#.
           .......##..
           .##.#.####.
           .##..##.##.
           ...........
           """) == 16
  end
end
