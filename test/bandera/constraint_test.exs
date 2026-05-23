defmodule Bandera.ConstraintTest do
  use ExUnit.Case, async: true
  alias Bandera.Constraint

  defp c(a, op, v), do: Constraint.new(a, op, v)

  test "eq / neq / in / not_in" do
    assert Constraint.match?(c("plan", :eq, "premium"), %{"plan" => "premium"})
    refute Constraint.match?(c("plan", :eq, "premium"), %{"plan" => "free"})
    assert Constraint.match?(c("plan", :neq, "free"), %{"plan" => "premium"})
    assert Constraint.match?(c("country", :in, ["US", "CA"]), %{"country" => "CA"})
    assert Constraint.match?(c("country", :not_in, ["US"]), %{"country" => "CA"})
  end

  test "numeric and string ordering" do
    assert Constraint.match?(c("age", :gte, 18), %{"age" => 18})
    assert Constraint.match?(c("age", :gt, 18), %{"age" => 21})
    refute Constraint.match?(c("age", :lt, 18), %{"age" => 18})
  end

  test "contains and regex matches" do
    assert Constraint.match?(c("email", :contains, "@acme.com"), %{"email" => "a@acme.com"})
    assert Constraint.match?(c("email", :matches, ".*@acme\\.com$"), %{"email" => "a@acme.com"})
  end

  test "missing attribute never matches" do
    refute Constraint.match?(c("plan", :eq, "premium"), %{})
  end

  describe "type coercion (string context vs numeric constraint)" do
    test "ordering compares numerically when the context value is a numeric string" do
      # The classic bug: "5" must NOT pass an >= 18 gate via term ordering.
      refute Constraint.match?(c("age", :gte, 18), %{"age" => "5"})
      assert Constraint.match?(c("age", :gte, 18), %{"age" => "25"})
      assert Constraint.match?(c("age", :gt, 18), %{"age" => "19"})
      refute Constraint.match?(c("age", :lt, 18), %{"age" => "18"})
      assert Constraint.match?(c("age", :lte, 18), %{"age" => "18"})
    end

    test "ordering against a non-numeric string vs a number fails closed" do
      refute Constraint.match?(c("age", :gt, 18), %{"age" => "old"})
      refute Constraint.match?(c("age", :lt, 18), %{"age" => "old"})
    end

    test "equality and membership coerce numeric strings" do
      assert Constraint.match?(c("id", :eq, 1), %{"id" => "1"})
      assert Constraint.match?(c("id", :in, [1, 2, 3]), %{"id" => "1"})
      # denylist: a banned id given as a string must still be caught
      refute Constraint.match?(c("id", :not_in, [666]), %{"id" => "666"})
    end

    test "plain string equality is unaffected" do
      assert Constraint.match?(c("plan", :eq, "premium"), %{"plan" => "premium"})
      refute Constraint.match?(c("plan", :eq, "premium"), %{"plan" => "1"})
    end

    test "string ordering still works for non-numeric strings" do
      assert Constraint.match?(c("tier", :gt, "gold"), %{"tier" => "platinum"})
    end
  end

  test "an uncompilable :matches pattern is a non-match, not a crash" do
    refute Constraint.match?(c("email", :matches, "([unclosed"), %{"email" => "a@acme.com"})
  end

  test "to_map / from_map round-trip" do
    constraint = c("country", :in, ["US", "CA"])
    assert constraint |> Constraint.to_map() |> Constraint.from_map() == constraint
  end
end
