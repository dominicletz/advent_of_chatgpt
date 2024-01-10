defmodule Day15Test do
  use ExUnit.Case

  test "check day 15" do
    assert Day15.evaluate("""
           rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
           """) == 1320
  end
end
