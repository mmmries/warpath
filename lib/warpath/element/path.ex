defmodule Warpath.Element.Path do
  @moduledoc false

  @type token ::
          {:root, String.t()}
          | {:property, String.t()}
          | {:identifier, String.t() | atom}
          | {:index_access, integer}

  @type t :: [token, ...]

  @spec accumulate(token, t) :: t
  def accumulate(token, acc) when is_list(acc), do: [token | acc]

  @spec bracketify(t) :: binary
  def bracketify(paths), do: make_path(paths, :bracketify)

  @spec dotify(t) :: binary
  def dotify(paths), do: make_path(paths, :dotify)

  defp make_path([h | _] = data, option) when is_tuple(h) do
    join(data, option)
  end

  defp make_path([h | _] = data, option) when is_list(h) do
    data
    |> Enum.map(&make_path(&1, option))
    |> List.flatten()
  end

  defp join(data, opts) do
    data
    |> Enum.reverse()
    |> Enum.map(&path(&1, opts))
    |> Enum.join()
  end

  defp path({:root, root}, :bracketify), do: root
  defp path({:root, root}, :dotify), do: root
  defp path({:property, property}, :bracketify), do: "['#{property}']"
  defp path({:property, property}, :dotify), do: ".#{property}"
  defp path({:index_access, index}, _), do: "[#{index}]"
end
