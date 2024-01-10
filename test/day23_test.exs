defmodule Day23Test do
  use ExUnit.Case

  test "check day 23" do
    assert Day23.evaluate("""
           #.#####################
           #.......#########...###
           #######.#########.#.###
           ###.....#.>.>.###.#.###
           ###v#####.#v#.###.#.###
           ###.>...#.#.#.....#...#
           ###v###.#.#.#########.#
           ###...#.#.#.......#...#
           #####.#.#.#######.#.###
           #.....#.#.#.......#...#
           #.#####.#.#.#########v#
           #.#...#...#...###...>.#
           #.#.#v#######v###.###v#
           #...#.>.#...>.>.#.###.#
           #####v#.#.###v#.#.###.#
           #.....#...#...#.#.#...#
           #.#########.###.#.#.###
           #...###...#...#...#.###
           ###.###.#.###v#####v###
           #...#...#.#.>.>.#.>.###
           #.###.###.#.###.#.#v###
           #.....###...###...#...#
           #####################.#
           """) == 94
  end
end