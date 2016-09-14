defmodule Elexir.FSMTest do
  use ExUnit.Case

  import Elexir.FSM

  test "generates regex for path with one token" do
    paths = [[{"an-token", 1}]]

    assert paths_to_patterns(paths) == [~r/^an-token$/]
  end

  test "generates regex for token path with multiple tokens" do
    paths = [[{"an-token", 1}, {"another-token", 1}]]

    assert paths_to_patterns(paths) == [~r/^an-token another-token$/]
  end

  test "generates regex for token path with multiple tokens and hole" do
    paths = [[{"an-token", 1}, {:hole, 1}, {"another-token", 1}]]

    assert paths_to_patterns(paths) == [~r/^an-token \S+ another-token$/]
  end

  test "generates regex for multiple token paths" do
    paths =
      [ [{"an-token", 2}, {:hole, 2}, {"another-token", 1}],
        [{"an-token", 2}, {:hole, 2}, {"some-token", 1}],
      ]

    assert paths_to_patterns(paths) ==
      [ ~r/^an-token \S+ another-token$/,
        ~r/^an-token \S+ some-token$/,
      ]
  end

  test "generates regex for token path with cycle" do
    paths = [[{"an-token", 1}, {"an-token", 1}, {:hole, 1}]]

    assert paths_to_patterns(paths) == [~r/^an-token an-token \S+$/]
  end
end
