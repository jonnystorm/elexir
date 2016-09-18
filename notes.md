### 2016-09-14 08:54

Write pattern generator for dealing with network device syntax.
Generator regex, replacing infrequently occurring tokens with "holes" (`\S+`).
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

    ```elixir
    # last transition                             next state            # times transition seen
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
    ```

1. Replace most infrequent tokens with holes

    ```elixir
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
    ```

1. Traverse FSM and produce path list

    ```elixir
    [ [{"an-token", 5}, {:hole, 5}, {"another-token", 5}, {"some-other-token", 5}],
      [{"an-token", 5}, {:hole, 5}, {"another-token", 5}, {"another-token", 1}, {"some-other-token", 1}],
    ]
    ```

1. Output regexp matching each path

    ```elixir
    ~r/^an-token \S+ another-token some-other-token$/
    ~r/^an-token \S+ another-token another-token some-other-token$/
    ```

### 2016-09-15 21:54

What to call this thing?

It's almost a first order Markov chain, but edges leaving a node don't always add up to 100%.
Also, there's a notion called *lumpability* that seems analogous to the "holes" being inserted.
However, lumpability only applies to continuous-time Markov chains, and I have yet to find a similar definition for discrete time in the literature.

### 2016-09-17 22:11

Writing integrated tests.

As expected, a loop forms when a next-state is the same as the two previous states.
Fortunately, a max loop counter is effectively included in every next-state entry.

Much more interesting, however, is the following, larger loop.

    22:44:12.135 [debug] Now at state :hole. Last state was "any".
    22:44:12.135 [debug] Now at state :hole. Last state was :hole.
    22:44:12.135 [info]  Loop detected at state :hole.
    22:44:12.135 [debug] Now at state "log". Last state was :hole.
    22:44:12.135 [debug] Now at state "any". Last state was :hole.
    22:44:12.135 [debug] Now at state :hole. Last state was "any".
    22:44:12.135 [debug] Now at state :hole. Last state was :hole.
    22:44:12.135 [info]  Loop detected at state :hole.


A global, TTL-like counter could handle this, but I'm not happy with the imprecision of that mechanism.
Need to re-evaluate the traversal algorithm with an eye to loop prevention.

### 2016-09-18 15:41

Rather than consuming a queue of next-states, consuming the counters, next-states, and, finally, transitions, in the state-machine provides correct loop prevention.
To do this, the last state and the next state must both come from the current path, but this makes more sense than keeping the two separate anyway.

