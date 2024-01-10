defmodule Day7Test do
  use ExUnit.Case

  test "check day 7" do
    assert Day7.evaluate("""
           32T3K 765
           T55J5 684
           KK677 28
           KTJJT 220
           QQQJA 483
           """) == 6440
  end
end
