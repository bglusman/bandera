if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Bandera.Dashboard.Similarity do
    @moduledoc """
    Pure helper for detecting suspiciously similar flag names in the dashboard.
    Uses Jaro distance to surface flag pairs that may be typos of each other.
    """

    @threshold 0.95

    @doc """
    Returns `[{atom, atom, float}]` pairs where the Jaro distance between the
    two flag name strings is >= #{@threshold}.

    Each pair is emitted once (a <= b lexicographically). Self-pairs are excluded.

    Assumes `flag_names` contains distinct atoms. Duplicate atoms in the input
    are treated as self-pairs and excluded.
    """
    @spec similar_pairs([atom]) :: [{atom, atom, float}]
    def similar_pairs(flag_names) when is_list(flag_names) do
      for {a, i} <- Enum.with_index(flag_names),
          sa = to_string(a),
          {b, j} <- Enum.with_index(flag_names),
          i < j,
          a != b,
          sb = to_string(b),
          score = String.jaro_distance(sa, sb),
          score >= @threshold do
        if sa <= sb, do: {a, b, score}, else: {b, a, score}
      end
    end
  end
end
