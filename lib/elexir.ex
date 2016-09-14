# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Elexir do
  def generate_patterns(input_string) when is_binary input_string do
    input_string
      |> Elexir.FSM.string_to_state_machine
      |> Elexir.FSM.replace_states_with_input_weight_below_threshold()  # WAT
      |> Elexir.FSM.paths_to_patterns
  end
end
