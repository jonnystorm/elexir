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

  test "finds no paths in state machine with only :begin and :end states" do
    fsm = %{{nil, :begin}  => %{:end => 1}, {:begin, :end} => %{}}

    assert find_all_paths(fsm) == [[]]
  end

  test "finds path in state machine with only one state" do
    fsm =
      %{{nil, :begin}        => %{"an-token" => 1},
        {:begin, "an-token"} => %{:end => 1},
        {"an-token", :end}   => %{},
      }

    assert find_all_paths(fsm) == [[{"an-token", 1}]]
  end

  test "finds path in another state machine with only one state" do
    fsm =
      %{{nil, :begin}             => %{"another-token" => 1},
        {:begin, "another-token"} => %{:end => 1},
        {"another-token", :end}   => %{},
      }

    assert find_all_paths(fsm) == [[{"another-token", 1}]]
  end

  test "finds path in acyclic state machine" do
    fsm =
      %{{nil, :begin}                 => %{"an-token" => 1},
        {:begin, "an-token"}          => %{"another-token" => 1},
        {"an-token", "another-token"} => %{:end => 1},
        {"another-token", :end}       => %{},
      }

    assert find_all_paths(fsm) == [[{"an-token", 1}, {"another-token", 1}]]
  end

  test "finds path in cyclic state machine" do
    fsm =
      %{{nil, :begin}            => %{"an-token" => 1},
        {:begin, "an-token"}     => %{"an-token" => 1},
        {"an-token", "an-token"} => %{:end => 1},
        {"an-token", :end}       => %{},
      }

    assert find_all_paths(fsm) == [[{"an-token", 1}, {"an-token", 1}]]
  end

  test "finds all paths in cyclic state machine" do
    fsm =
      %{{nil, :begin}                          => %{"an-token"         => 5},
        {:begin, "an-token"}                   => %{:hole              => 5},
        {"an-token", :hole}                    => %{"another-token"    => 5},
        {:hole, "another-token"}               => %{"some-other-token" => 4,
                                                    "another-token"    => 1,
                                                  },
        {"another-token", "another-token"}     => %{"some-other-token" => 1},
        {"another-token", "some-other-token"}  => %{:end               => 5},
        {"some-other-token", :end}             => %{},
      }

    assert find_all_paths(fsm) ==
      [ [{"an-token", 5}, {:hole, 5}, {"another-token", 5}, {"some-other-token", 4}],
        [{"an-token", 5}, {:hole, 5}, {"another-token", 5}, {"another-token", 1}, {"some-other-token", 1}],
      ]
  end

  test "raises error for probability threshold less than 0" do
    assert_raise FunctionClauseError, fn ->
      merge_low_probability_states(%{}, -0.1)
    end
  end

  test "raises error for probability threshold greater than 1" do
    assert_raise FunctionClauseError, fn ->
      merge_low_probability_states(%{}, 1.1)
    end
  end

  test "creates no holes in empty state machine" do
    fsm = %{{nil, :begin}  => %{:end => 1}, {:begin, :end} => %{}}

    assert merge_low_probability_states(fsm, 1) == fsm
  end

  test "creates no holes in state machine with only one state" do
    fsm =
      %{{nil, :begin}        => %{"an-token" => 1},
        {:begin, "an-token"} => %{:end => 1},
        {"an-token", :end}   => %{},
      }

    assert merge_low_probability_states(fsm, 1) == fsm
  end

  test "converts a low-probability state to a hole" do
    fsm =
      %{{nil, :begin}                      => %{"high-probability state" => 2,
                                                "low-probability state"  => 1
                                              },
        {:begin, "high-probability state"} => %{:end => 2},
        {:begin, "low-probability state"}  => %{:end => 1},
        {"high-probability state", :end}   => %{},
        {"low-probability state", :end}    => %{},
      }

    assert merge_low_probability_states(fsm, 2/3) ==
      %{{nil, :begin}                      => %{"high-probability state" => 2,
                                                :hole                    => 1,
                                              },
        {:begin, "high-probability state"} => %{:end => 2},
        {:begin, :hole}                    => %{:end => 1},
        {"high-probability state", :end}   => %{},
        {:hole, :end}                      => %{},
      }
  end

  test "merges low-probability states into holes" do
    fsm =
      %{{nil, :begin}                          => %{"an-token"         => 5},
        {:begin, "an-token"}                   => %{"user-input1"      => 3,
                                                    "user-input2"      => 2,
                                                  },
        {"an-token", "user-input1"}            => %{"another-token"    => 3},
        {"an-token", "user-input2"}            => %{"another-token"    => 2},
        {"user-input1", "another-token"}       => %{"some-other-token" => 2,
                                                    "another-token"    => 1,
                                                  },
        {"user-input2", "another-token"}       => %{"some-other-token" => 2},
        {"another-token", "another-token"}     => %{"some-other-token" => 1},
        {"another-token", "some-other-token"}  => %{:end               => 5},
        {"some-other-token", :end}             => %{},
      }

    assert merge_low_probability_states(fsm, 5/21) ==
      %{{nil, :begin}                          => %{"an-token"         => 5},
        {:begin, "an-token"}                   => %{:hole              => 5},
        {"an-token", :hole}                    => %{"another-token"    => 5},
        {:hole, "another-token"}               => %{"some-other-token" => 4,
                                                    "another-token"    => 1,
                                                  },
        {"another-token", "another-token"}     => %{"some-other-token" => 1},
        {"another-token", "some-other-token"}  => %{:end               => 5},
        {"some-other-token", :end}             => %{},
      }
  end
end
