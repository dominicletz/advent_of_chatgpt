defmodule Day1Test do
  test "check day 1" do
    assert Day1.evaluate("""
           1abc2
           pqr3stu8vwx
           a1b2c3d4e5f
           treb7uchet
           """) == 142
  end
end
