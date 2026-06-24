defmodule Bandera.Dashboard.SimilarityTest do
  use ExUnit.Case, async: true

  alias Bandera.Dashboard.Similarity

  describe "similar_pairs/1" do
    test "returns empty list for fewer than two flags" do
      assert Similarity.similar_pairs([]) == []
      assert Similarity.similar_pairs([:one]) == []
    end

    test "returns empty list when no flags are similar" do
      flags = [:checkout, :dark_mode, :billing]
      assert Similarity.similar_pairs(flags) == []
    end

    test "detects a near-duplicate pair above threshold" do
      # jaro_distance("checkout", "chekout") should be >= 0.95
      pairs = Similarity.similar_pairs([:checkout, :chekout])
      assert length(pairs) == 1
      [{a, b, score}] = pairs
      assert {a, b} in [{:checkout, :chekout}, {:chekout, :checkout}]
      assert is_float(score)
      assert score >= 0.95
    end

    test "does not emit self-pairs" do
      pairs = Similarity.similar_pairs([:checkout, :checkout])
      assert pairs == []
    end

    test "emits each pair only once (no duplicates)" do
      pairs = Similarity.similar_pairs([:checkout, :chekout, :billing])
      assert length(pairs) == length(Enum.uniq(pairs))
      # Confirm {a,b} is not also emitted as {b,a}
      pair_names = Enum.map(pairs, fn {a, b, _} -> MapSet.new([a, b]) end)
      assert length(pair_names) == length(Enum.uniq(pair_names))
    end

    test "pair order is deterministic: a <= b lexicographically" do
      [{a, b, _}] = Similarity.similar_pairs([:chekout, :checkout])
      assert to_string(a) <= to_string(b)
    end

    test "score is the jaro distance value" do
      [{_a, _b, score}] = Similarity.similar_pairs([:checkout, :chekout])
      expected = String.jaro_distance("checkout", "chekout")
      assert_in_delta score, expected, 0.0001
    end

    test "genuinely different flags with low jaro distance are excluded" do
      # jaro_distance("flag_v1", "flag_v2") ~= 0.905, which is < 0.95
      pairs = Similarity.similar_pairs([:flag_v1, :flag_v2])
      assert pairs == []
    end
  end
end
