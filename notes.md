### 2016-09-14 08:54

Write grammar generator for dealing with network device syntax.
Generator regex, replacing infrequently occurring tokens with "holes" (\S+).
For a large enough data set, it is assumed frequently occuring tokens are built-in syntax.
Holes are to match user input.
Frequency is determined by a count kept for each token transition.

Grammar is directed, cyclic graph.
Loop is prevention relaxed to tolerate cycles.
Cycles are bounded by the maximum number of times any one node (token) should be seen during traversal.

#### Example input

    an-token user-input1 another-token some-other-token
    an-token user-input1 another-token some-other-token
    an-token user-input1 another-token another-token some-other-token
    an-token user-input2 another-token some-other-token
    an-token user-input2 another-token some-other-token

#### Corresponding state graph

                    :begin
                       | 5
                       v
                    an-token
                   / 3   2 \  
                  v         v
           user-input1  user-input2
                   \ 3   2 /
                 _  \     /
                / v  v   v
             1 |  another-token
                \_/    | 5
                       v
                some-other-token
                       | 5
                       v
                     :end

1. Build finite state machine

    # last transition                             next state            # times transition seen
    %{{nil, :begin}                          => %{"an-token"         => 5}},
      {:begin, "an-token"}                   => %{"user-input1"      => 3,
                                                  "user-input2"      => 2,
                                                },
                                                
      {"an-token", "user-input1"}            => %{"another-token"    => 3}},
      {"an-token", "user-input2"}            => %{"another-token"    => 2}},
      {"user-input1", "another-token"}       => %{"some-other-token" => 2,
                                                  "another-token"    => 1,
                                                }
                                                
      {"user-input2", "another-token"}       => %{"some-other-token" => 2}},
      {"another-token", "another-token"}     => %{"some-other-token" => 1}},
      {"another-token", "some-other-token"}  => %{:end,              => 5}},
      {"some-other-token", :end}             => %{}},
    }

1. Replace most infrequent tokens with holes

    # last transition                             next transition       # times transition seen
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

1. Traverse FSM and produce path list

    [ [{"an-token", 5}, {:hole, 5}, {"another-token", 5}, {"some-other-token", 5}],
      [{"an-token", 5}, {:hole, 5}, {"another-token", 5}, {"another-token", 1}, {"some-other-token", 1}],
    ]

1. Output regexp matching each path

    ~r/^an-token \S+ another-token some-other-token$/
    ~r/^an-token \S+ another-token another-token some-other-token$/

