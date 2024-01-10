defmodule Day10Test do
  use ExUnit.Case

  test "check day 10" do
    assert Day10.evaluate("""
           .....
           .S-7.
           .|.|.
           .L-J.
           .....
           """) == 4

    assert Day10.evaluate("""
           ..F7.
           .FJ|.
           SJ.L7
           |F--J
           LJ...
           """) == 8
  end
end
