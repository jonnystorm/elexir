# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Elexir.FSM do
  @moduledoc false

  require Logger

  defp calculate_path_weight(path) do
    path
      |> Enum.map(& elem(&1, 1))
      |> Enum.sum
  end

  defp _find_all_paths(_path, [], _fsm, acc) do
    Enum.sort_by(acc, &calculate_path_weight/1, &>=/2)
  end
  defp _find_all_paths([], [[]|q], fsm, acc) do
    _find_all_paths([], q, fsm, acc)
  end
  defp _find_all_paths(path, [[{:end, _}|t]|q], fsm, acc) do
    [{:begin, 0}|completed_path] = Enum.reverse(path)

    _find_all_paths(path, [t|q], fsm, [completed_path|acc])
  end
  defp _find_all_paths([_|path], [[]|q], fsm, acc) do
    _find_all_paths(path, q, fsm, acc)
  end
  defp _find_all_paths([{last_state, _}|_] = path, [[h|t]|q], fsm, acc) do
    {state, _}  = h
    transition  = {last_state, state}

    :ok = Logger.debug("Now at state #{inspect state}. Last state was #{inspect last_state}.")

    next_states_map = fsm[transition]

    if is_nil(next_states_map) do
      IO.inspect(transition)
    end

    next_states = Enum.into(next_states_map, [])

    _find_all_paths([h|path], [next_states, t|q], fsm, acc)
  end

  def find_all_paths(state_machine) do
    initial_transition = {nil, :begin}
    next_states = Enum.into(state_machine[initial_transition], [])

    if is_nil(next_states) do
      :ok = Logger.error("No next-states for :begin transition in the given state machine!")

      {:error, :einval}
    end

    _find_all_paths([{:begin, 0}], [next_states], state_machine, [])
  end

  defp _paths_to_patterns([], {_, regexps}) do
    Enum.reverse(regexps)
  end
  defp _paths_to_patterns([[] | paths], {pattern, regexps}) do
    _paths_to_patterns(paths, {"", [~r"^#{pattern}$" | regexps]})
  end
  defp _paths_to_patterns([[{:hole, _}|rest] | paths], {"", regexps}) do
    _paths_to_patterns([rest | paths], {"\\S+", regexps})
  end
  defp _paths_to_patterns([[{:hole, _}|rest] | paths], {pattern, regexps}) do
    _paths_to_patterns([rest | paths], {"#{pattern} \\S+", regexps})
  end
  defp _paths_to_patterns([[{token, _}|rest] | paths], {"", regexps}) do
    _paths_to_patterns([rest | paths], {token, regexps})
  end
  defp _paths_to_patterns([[{token, _}|rest] | paths], {pattern, regexps}) do
    _paths_to_patterns([rest | paths], {"#{pattern} #{token}", regexps})
  end

  def paths_to_patterns([[{token, _}|rest] | paths]) do
    _paths_to_patterns([rest | paths], {token, []})
  end
end
