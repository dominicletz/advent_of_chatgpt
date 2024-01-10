defmodule Day13Test do
  use ExUnit.Case

  test "check day 13" do
    assert Day13.evaluate("""
           #.##..##.
           ..#.##.#.
           ##......#
           ##......#
           ..#.##.#.
           ..##..##.
           #.#.##.#.

           #...##..#
           #....#..#
           ..##..###
           #####.##.
           #####.##.
           ..##..###
           #....#..#
           """) == 405
  end
end
