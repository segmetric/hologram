defmodule Hologram.Compiler.IR do
  alias Hologram.Compiler.AST
  alias Hologram.Compiler.Transformer

  # --- OPERATORS ---

  defmodule AdditionOperator do
    defstruct left: nil, right: nil
  end

  defmodule ConsOperator do
    defstruct head: nil, tail: nil
  end

  defmodule MatchOperator do
    defstruct left: nil, right: nil
  end

  # --- DATA TYPES ---

  defmodule AtomType do
    defstruct value: nil

    @type t :: %__MODULE__{value: atom}
  end

  defmodule BinaryType do
    defstruct parts: []
  end

  defmodule BooleanType do
    defstruct value: nil
  end

  defmodule FloatType do
    defstruct value: nil
  end

  defmodule IntegerType do
    defstruct value: nil
  end

  defmodule ListType do
    defstruct data: []
  end

  defmodule MapType do
    defstruct data: []
  end

  defmodule ModuleType do
    defstruct module: nil, segments: nil
  end

  defmodule NilType do
    defstruct []
  end

  defmodule StringType do
    defstruct value: nil
  end

  defmodule StructType do
    defstruct module: nil, data: []
  end

  defmodule TupleType do
    defstruct data: []
  end

  # --- CONTROL FLOW ---

  defmodule Alias do
    defstruct segments: nil
  end

  defmodule Symbol do
    defstruct name: nil
  end

  # --- API ---

  @doc """
  Given Elixir source code returns its Hologram IR.

  ## Examples

      iex> IR.for_code("1 + 2")
      %IR.AdditionOperator{left: %IR.IntegerType{value: 1}, right: %IR.IntegerType{value: 2}}
  """
  def for_code(code) do
    code
    |> AST.for_code()
    |> Transformer.transform()
  end
end
