defmodule Day14Test do
  use ExUnit.Case

  test "check day 14" do
    assert Day14.evaluate("""
           O....#....
           O.OO#....#
           .....##...
           OO.#O....O
           .O.....O#.
           O.#..O.#.#
           ..O..#O..O
           .......O..
           #....###..
           #OO..#....
           """) == 136
  end
end
