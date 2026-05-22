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

  test "to_map / from_map round-trip" do
    constraint = c("country", :in, ["US", "CA"])
    assert constraint |> Constraint.to_map() |> Constraint.from_map() == constraint
  end
end
