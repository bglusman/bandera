defmodule Bandera.Constraint do
  @moduledoc "A single targeting predicate evaluated against an evaluation context."

  @enforce_keys [:attribute, :operator, :values]
  defstruct [:attribute, :operator, :values]

  @operators [:eq, :neq, :in, :not_in, :contains, :gt, :gte, :lt, :lte, :matches]

  @type t :: %__MODULE__{attribute: String.t(), operator: atom, values: [term]}

  @spec new(String.t(), atom, term) :: t
  def new(attribute, operator, values)
      when is_binary(attribute) and operator in @operators do
    %__MODULE__{attribute: attribute, operator: operator, values: List.wrap(values)}
  end

  @spec match?(t, map) :: boolean
  def match?(%__MODULE__{attribute: a, operator: op, values: values}, context) do
    apply_op(op, Map.get(context, a), values)
  end

  defp apply_op(_op, nil, _values), do: false
  defp apply_op(:eq, actual, [v]), do: actual == v
  defp apply_op(:neq, actual, [v]), do: actual != v
  defp apply_op(:in, actual, values), do: actual in values
  defp apply_op(:not_in, actual, values), do: actual not in values

  defp apply_op(:contains, actual, [v]) when is_binary(actual) and is_binary(v),
    do: String.contains?(actual, v)

  defp apply_op(:gt, actual, [v]), do: compare(actual, v) == :gt
  defp apply_op(:gte, actual, [v]), do: compare(actual, v) in [:gt, :eq]
  defp apply_op(:lt, actual, [v]), do: compare(actual, v) == :lt
  defp apply_op(:lte, actual, [v]), do: compare(actual, v) in [:lt, :eq]

  defp apply_op(:matches, actual, [pattern]) when is_binary(actual) and is_binary(pattern),
    do: Regex.match?(Regex.compile!(pattern), actual)

  defp apply_op(_op, _actual, _values), do: false

  defp compare(a, b) when a > b, do: :gt
  defp compare(a, b) when a < b, do: :lt
  defp compare(_a, _b), do: :eq

  @spec to_map(t) :: map
  def to_map(%__MODULE__{attribute: a, operator: op, values: v}),
    do: %{"attribute" => a, "operator" => Atom.to_string(op), "values" => v}

  @spec from_map(map) :: t
  def from_map(%{"attribute" => a, "operator" => op, "values" => v}),
    do: new(a, String.to_existing_atom(op), v)
end
