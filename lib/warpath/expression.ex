defmodule Warpath.Expression do
  @moduledoc """
    This module contains functions to compile a jsonpath query string.
  """

  alias Warpath.Expression.Parser
  alias Warpath.Expression.Tokenizer
  alias Warpath.ExpressionError

  defstruct tokens: nil

  @type root :: {:root, String.t()}

  @type property :: {:property, String.t() | atom()}

  @type dot_access :: {:dot, property}

  @type subpath_expression :: {:subpath_expression, keyword()}

  @type has_children :: {:has_children?, subpath_expression()}

  @type indexes :: {:indexes, [{:index_access, integer()}, ...]}

  @type slice ::
          {:slice,
           [
             {:start_index, integer()},
             {:end_index, integer()},
             {:step, non_neg_integer()}
           ]}

  @type wildcard :: {:wildcard, :*}

  @type union_property :: {:union, [dot_access(), ...]}

  @type operator :: :< | :> | :<= | :>= | :== | :!= | :=== | :!== | :not | :and | :or | :in

  @type guard ::
          :is_atom
          | :is_binary
          | :is_boolean
          | :is_float
          | :is_integer
          | :is_list
          | :is_map
          | :is_nil
          | :is_number
          | :is_tuple

  @type filter :: {:filter, has_children | {operator | guard, subpath_expression() | term}}

  @type scan :: {:scan, property | wildcard | filter | indexes}

  @type token ::
          root()
          | indexes()
          | slice()
          | dot_access()
          | filter()
          | scan()
          | union_property()
          | wildcard()

  @type t :: %__MODULE__{tokens: nonempty_list(token())}

  @doc """
  Compile a jsonpath string query

  ## Example
      iex> Warpath.Expression.compile("$.post.author")
      {:ok, %Warpath.Expression{tokens: [ {:root, "$"}, {:dot, {:property, "post"}}, {:dot, {:property, "author"}} ]}}
  """
  @spec compile(String.t()) :: {:ok, t()} | {:error, ExpressionError.t()}
  def compile(expression) when is_binary(expression) do
    with {:ok, tokens} <- Tokenizer.tokenize(expression),
         {:ok, expression_tokens} <- Parser.parse(tokens) do
      {:ok, %Warpath.Expression{tokens: expression_tokens}}
    else
      {:error, error} ->
        message = Exception.message(error)
        {:error, ExpressionError.exception(message)}
    end
  end

  @doc """
  Compiles jsonpath string query to expression.

  ## Examples
      iex> import Warpath.Expression
      iex> ~q"$.post.author"
      %Warpath.Expression{tokens: [ {:root, "$"}, {:dot, {:property, "post"}}, {:dot, {:property, "author"}} ]}
  """
  defmacro sigil_q({:<<>>, _meta, _pieces} = selector, _modifiers) do
    quote do
      case compile(unquote(selector)) do
        {:ok, expression} ->
          expression

        {:error, error} ->
          raise error
      end
    end
  end
end
