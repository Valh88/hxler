defmodule ExampleTest do
  use ExUnit.Case, async: false

  test "add/2 returns the sum of two ints" do
    assert Example.MyNif.add(20, 22) == 42
  end

  test "greet/1 returns a greeting string" do
    assert Example.MyNif.greet("hxler") == "Hello, hxler!"
  end
end
