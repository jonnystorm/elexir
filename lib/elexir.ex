# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Elexir do
  def generate_patterns(input_string, threshold)
      when is_binary(input_string)
       and 0 <= threshold and threshold <= 1
  do
    input_string
      |> Elexir.FSM.string_to_state_machine
      |> IO.inspect
      |> Elexir.FSM.merge_low_probability_states(threshold)
      |> IO.inspect
      |> Elexir.FSM.find_all_paths
      |> Elexir.FSM.paths_to_patterns
  end
end
