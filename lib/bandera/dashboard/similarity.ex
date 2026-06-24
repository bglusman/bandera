if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Bandera.Dashboard.Similarity do
    @threshold 0.95

    @doc """
    Returns `[{atom, atom, float}]` pairs where the Jaro distance between the
    two flag name strings is >= #{@threshold}.

    Each pair is emitted once (a <= b lexicographically). Self-pairs are excluded.
    """
    @spec similar_pairs([atom]) :: [{atom, atom, float}]
    def similar_pairs(flag_names) when is_list(flag_names) do
      for {a, i} <- Enum.with_index(flag_names),
          {b, j} <- Enum.with_index(flag_names),
          i < j,
          a != b,
          score = String.jaro_distance(to_string(a), to_string(b)),
          score >= @threshold do
        if to_string(a) <= to_string(b), do: {a, b, score}, else: {b, a, score}
      end
    end
  end
end
