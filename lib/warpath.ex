defmodule Warpath do
  @moduledoc """
    Public api for query elixir data strucutre as JsonPath proposal on https://goessner.net/articles/JsonPath/
  """

  alias Warpath.Element.Path
  alias Warpath.Element.PathMarker
  alias Warpath.EnumWalker
  alias Warpath.Expression
  alias Warpath.Filter
  alias Warpath.Scanner
  alias Warpath.UnsupportedOperationError

  defguardp is_container(term) when is_list(term) or is_map(term)

  @spec query(any, String.t(), result_type: :value | :path | :value_path) :: any
  def query(data, string, opts \\ []) when is_binary(string) do
    with {:ok, expression} <- Expression.compile(string),
         {:ok, elements} <- do_query(data, expression) do
      {:ok, collect(elements, opts[:result_type])}
    else
      error ->
        error
    end
  end

  defp do_query(document, tokens) when is_list(tokens) do
    terms = Enum.reduce(tokens, {document, []}, &transform(&2, &1))
    {:ok, terms}
  rescue
    e in UnsupportedOperationError -> {:error, e}
  end

  defp transform({member, path}, {:root, _} = token),
    do: {member, Path.accumulate(token, path)}

  defp transform({members, path} = element, {:dot, {:property, name} = property} = token)
       when is_list(members) do
    if Keyword.keyword?(members) do
      access(element, token)
    else
      tips =
        "You are trying to traverse a list using dot " <>
          "notation '#{Path.accumulate(property, path) |> Path.dotify()}', " <>
          "that it's not allowed for list type. " <>
          "You can use something like '#{Path.dotify(path)}[*].#{name}' instead."

      raise UnsupportedOperationError, tips
    end
  end

  defp transform({member, _} = element, {:dot, _} = dot_token) when is_map(member),
    do: access(element, dot_token)

  defp transform({_, _} = element, {:array_indexes, indexes}),
    do: Enum.map(indexes, &transform(element, &1))

  defp transform({members, path}, {:index_access, index} = token) when is_list(members) do
    {Enum.at(members, index), Path.accumulate(token, path)}
  end

  defp transform({members, _} = element, {:wildcard, :*}) when is_container(members) do
    element
    |> PathMarker.stream()
    |> Enum.to_list()
  end

  defp transform(element, {:filter, filter_expression}),
    do: Filter.filter(element, filter_expression)

  defp transform(element, {:scan, {tag, _} = target}) when tag in [:property, :wildcard],
    do: Scanner.scan(element, target, &Path.accumulate/2)

  defp transform(element, {:scan, {:filter, _} = filter}),
    do: do_scan_filter([element], filter)

  defp transform(element, {:scan, {:array_indexes, _} = indexes}),
    do: do_scan_filter(element, indexes)

  defp transform([element | []], token), do: transform(element, token)

  defp transform(members, token) when is_list(members),
    do: Enum.map(members, &transform(&1, token))

  defp transform({_member, path}, token) do
    raise UnsupportedOperationError,
          "token=#{inspect(token)}, path=#{inspect(path)}"
  end

  defp access({member, path}, {:dot, {:property, key} = token}) do
    {member[key], Path.accumulate(token, path)}
  end

  defp do_scan_filter(enumerable, filter) do
    enumerable
    |> EnumWalker.reduce_while([], container_reducer(), &Path.accumulate/2)
    |> Stream.filter(fn {member, _} -> is_list(member) end)
    |> Enum.flat_map(fn element -> transform(element, filter) end)
  end

  defguardp has_itens(container)
            when (is_list(container) and container != []) or
                   (is_map(container) and map_size(container) > 0)

  defp container_reducer do
    fn {container, _} = element, acc ->
      case container do
        container when has_itens(container) ->
          {:walk, [element | acc]}

        _ ->
          {:skip, acc}
      end
    end
  end

  defp collect(elements, opt) when is_list(elements), do: Enum.map(elements, &collect(&1, opt))
  defp collect({member, path}, :value_path), do: {member, Path.bracketify(path)}
  defp collect({_, path}, :path), do: Path.bracketify(path)
  defp collect({member, _}, _), do: member
end
