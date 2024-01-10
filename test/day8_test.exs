defmodule Day8Test do
  use ExUnit.Case

  test "check day 8" do
    assert Day8.evaluate("""
           RL

           AAA = (BBB, CCC)
           BBB = (DDD, EEE)
           CCC = (ZZZ, GGG)
           DDD = (DDD, DDD)
           EEE = (EEE, EEE)
           GGG = (GGG, GGG)
           ZZZ = (ZZZ, ZZZ)
           """) == 2

    assert Day8.evaluate("""
           LLR

           AAA = (BBB, BBB)
           BBB = (AAA, ZZZ)
           ZZZ = (ZZZ, ZZZ)
           """) == 6
  end
end
