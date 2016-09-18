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

  defp _find_all_paths([{nil, _}], _context, acc) do
    Enum.sort_by(acc, &calculate_path_weight/1, &<=/2)
  end
  defp _find_all_paths(_path, [], acc) do
    Enum.sort_by(acc, &calculate_path_weight/1, &<=/2)
  end
  defp _find_all_paths(
    [{:end, _}|[{:begin, _}|_] = last_path],
    [_|past_context],
    acc
  ) do
    _find_all_paths(last_path, past_context, acc)
  end
  defp _find_all_paths([{:end, _}|last_path], [_|past_context], acc) do
    [_, {:begin, _}|completed_path] = Enum.reverse(last_path)

    new_acc = [completed_path|acc]

    _find_all_paths(last_path, past_context, new_acc)
  end
  defp _find_all_paths([_|path], [fsm|context], acc) when fsm == %{} do
    _find_all_paths(path, context, acc)
  end
  defp _find_all_paths(
    [{state, _}|[{last_state, _}|_] = last_path] = path,
    [fsm|past_context],
    acc
  ) do
    :ok = Logger.debug("Transitioning from state #{inspect last_state} to state #{inspect state}.")
    :ok = Logger.debug("Current context is #{inspect fsm}.")
    :ok = Logger.debug("Path is #{inspect path}.")

    case take_next_state(fsm, {last_state, state}) do
      {nil, _} ->
        [_|next_path]    = last_path
        [_|next_context] = past_context

        _find_all_paths(next_path, next_context, acc)

      {next_state, new_fsm} ->
        next_path = [next_state|path]

        _find_all_paths(next_path, [new_fsm, new_fsm|past_context], acc)
    end
  end

  def find_all_paths(state_machine) when is_map state_machine do
    initial_transition = {nil, :begin}
    next_states = state_machine[initial_transition]

    if is_nil(next_states) do
      :ok = Logger.error("No next-states for :begin transition in the given state machine!")

      {:error, :einval}
    end

    begin_count = Enum.sum(Map.values(next_states)) - 1
    initial_path = [{:begin, begin_count}, {nil, begin_count}]

    _find_all_paths(initial_path, [state_machine, state_machine], [])
  end

  defp _take_next_state(fsm, transition) do
    Map.get_and_update(fsm, transition, fn
      nil ->
        {nil, fsm}

      next_states ->
        case Enum.take(next_states, 1) do
          [] ->
            {nil, []}

          [{state, _} = entry] ->
            {entry, Map.delete(next_states, state)}
        end
    end)
  end

  defp take_next_state(fsm, transition) do
    with {entry, %{^transition => next_states}} when next_states == %{} <-
        _take_next_state(fsm, transition)
    do
      {entry, Map.delete(fsm, transition)}
    end
  end

  defp merge_maps_by_adding_values(map1, map2) do
    Map.merge(map1, map2, fn(_, a, b) -> a + b end)
  end

  defp replace_states(fsm, replace_map, new_state) do
    fsm
      |> Enum.map(fn {{s1, s2}, next_states} ->
        new_s1 = (Map.has_key?(replace_map, s1) && new_state) || s1
        new_s2 = (Map.has_key?(replace_map, s2) && new_state) || s2

        new_next_states =
          Enum.reduce(next_states, %{}, fn({state, count}, acc) ->
            if Map.has_key?(replace_map, state) do
              merge_maps_by_adding_values(acc, %{new_state => count})

            else
              merge_maps_by_adding_values(acc, %{state => count})
            end
          end)

        {{new_s1, new_s2}, new_next_states}
      end)
      |> Enum.reduce(%{}, fn({{s1, s2}, next_states}, acc) ->
        Map.merge(acc, %{{s1, s2} => next_states}, fn(_, a, b) ->
          merge_maps_by_adding_values(a, b)
        end)
      end)
  end

  defp ceiling(0), do: 0
  defp ceiling(num) when trunc(num) / num  < 1.0, do: trunc(num + 1)
  defp ceiling(num) when trunc(num) / num == 1.0, do: trunc(num)

  def merge_low_probability_states(state_machine, threshold)
      when 0 <= threshold and threshold <= 1 do

    transitions_per_state =
      state_machine
        |> Map.values
        |> Enum.reduce(%{}, fn(next_states, acc) ->
          acc
            |> merge_maps_by_adding_values(next_states)
            |> Map.delete(:end)
        end)

    total_transitions = Enum.sum Map.values(transitions_per_state)
      min_transitions = ceiling(total_transitions * threshold)

    low_probability_states =
      transitions_per_state
        |> Stream.filter(& elem(&1, 1) < min_transitions)
        |> Stream.filter(& elem(&1, 0) != :end)
        |> Enum.into(%{})

    :ok = Logger.debug("Found #{total_transitions} transitions in state machine.")
    :ok = Logger.debug("Found the following states with fewer than #{min_transitions} transitions: #{inspect low_probability_states}.")

    replace_states(state_machine, low_probability_states, :hole)
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

  def paths_to_patterns([[]]), do: []
  def paths_to_patterns([[{token, _}|rest] | paths]) do
    _paths_to_patterns([rest | paths], {token, []})
  end

  defp merge_state_machines(fsm1, fsm2) do
    Map.merge(fsm1, fsm2, fn(_, next_states1, next_states2) ->
      merge_maps_by_adding_values(next_states1, next_states2)
    end)
  end

  defp _line_to_state_machine([], {_, :end} = transition, acc) do
    entry = %{transition => %{}}

    merge_state_machines(acc, entry)
  end
  defp _line_to_state_machine([], {_, state} = transition, acc) do
    next_transition = {state, :end}
    entry = %{transition => %{:end => 1}}
    next_acc = merge_state_machines(acc, entry)

    _line_to_state_machine([], next_transition, next_acc)
  end
  defp _line_to_state_machine([next_state|rest], {_, state} = transition, acc) do
    next_transition = {state, next_state}
    entry = %{transition => %{next_state => 1}}
    next_acc = merge_state_machines(acc, entry)

    _line_to_state_machine(rest, next_transition, next_acc)
  end

  defp line_to_state_machine(string) do
    _line_to_state_machine(String.split(string), {nil, :begin}, %{})
  end

  def string_to_state_machine(string) when is_binary string do
    string
      |> String.split("\n")
      |> Enum.map(&line_to_state_machine/1)
      |> Enum.reduce(%{}, fn(line_fsm, acc) ->
        merge_state_machines(acc, line_fsm)
      end)
  end
end
