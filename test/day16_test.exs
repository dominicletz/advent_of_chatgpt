defmodule Day16Test do
  use ExUnit.Case

  test "check day 16" do
    assert Day16.evaluate("""
           .|...\....
           |.-.\.....
           .....|-...
           ........|.
           ..........
           .........\
           ..../.\\..
           .-.-/..|..
           .|....-|.\
           ..//.|....
           """) == 46
  end
end
