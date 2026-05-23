defmodule Bandera.ConstraintPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Bandera.Constraint

  property ":eq match is always true when context carries the exact value" do
    check all(
            attribute <- string(:alphanumeric, min_length: 1),
            value <- one_of([integer(), string(:alphanumeric)])
          ) do
      context = %{attribute => value}
      constraint = Constraint.new(attribute, :eq, value)
      assert Constraint.match?(constraint, context)
    end
  end

  property ":in and :not_in are complements for any single-element list" do
    check all(
            attribute <- string(:alphanumeric, min_length: 1),
            value <- string(:alphanumeric, min_length: 1),
            other <- string(:alphanumeric, min_length: 1),
            attribute != "" and value != other
          ) do
      context = %{attribute => value}
      in_constraint = Constraint.new(attribute, :in, [value])
      not_in_constraint = Constraint.new(attribute, :not_in, [value])
      assert Constraint.match?(in_constraint, context)
      refute Constraint.match?(not_in_constraint, context)

      other_context = %{attribute => other}

      refute Constraint.match?(in_constraint, other_context) ==
               Constraint.match?(not_in_constraint, other_context)
    end
  end

  property "missing attribute never matches any operator" do
    check all(
            attribute <- string(:alphanumeric, min_length: 1),
            value <- one_of([integer(), string(:alphanumeric)]),
            operator <- member_of([:eq, :neq, :in, :not_in, :gt, :gte, :lt, :lte])
          ) do
      constraint = Constraint.new(attribute, operator, value)
      refute Constraint.match?(constraint, %{})
    end
  end
end
