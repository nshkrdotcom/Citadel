defmodule CitadelTest do
  use ExUnit.Case
  doctest Citadel

  test "greets the world" do
    assert Citadel.hello() == :world
  end
end
