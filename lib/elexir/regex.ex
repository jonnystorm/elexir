# Copyright © 2016 Jonathan Storm <the.jonathan.storm@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more details.

defmodule Elexir.FSM do
  @moduledoc false

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
