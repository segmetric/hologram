defmodule Hologram.Compiler.Transformer do
  if Application.compile_env(:hologram, :debug_transformer) do
    use Interceptor.Annotated,
      config: %{
        {Hologram.Compiler.Transformer, :transform, 1} => [
          after: {Hologram.Compiler.Transformer, :debug, 2}
        ]
      }
  end

  alias Hologram.Compiler.IR

  @doc """
  Transforms Elixir AST to Hologram IR.

  ## Examples
      iex> ast = quote do 1 + 2 end
      {:+, [context: Elixir, imports: [{1, Kernel}, {2, Kernel}]], [1, 2]}
      iex> Transformer.transform(ast)
      %IR.AdditionOperator{left: %IR.IntegerType{value: 1}, right: %IR.IntegerType{value: 2}}
  """
  @intercept true
  def transform(ast)

  # --- DATA TYPES ---

  def transform(ast) when is_atom(ast) and ast not in [nil, false, true] do
    %IR.AtomType{value: ast}
  end

  def transform({:<<>>, _, parts}) do
    %IR.BinaryType{parts: transform_list(parts)}
  end

  def transform(ast) when is_boolean(ast) do
    %IR.BooleanType{value: ast}
  end

  def transform(ast) when is_float(ast) do
    %IR.FloatType{value: ast}
  end

  def transform(ast) when is_integer(ast) do
    %IR.IntegerType{value: ast}
  end

  def transform(ast) when is_list(ast) do
    data = Enum.map(ast, &transform/1)
    %IR.ListType{data: data}
  end

  def transform(nil) do
    %IR.NilType{}
  end

  def transform(ast) when is_binary(ast) do
    %IR.StringType{value: ast}
  end

  def transform({:{}, _, data}) do
    build_tuple_type_ir(data)
  end

  def transform({_, _} = data) do
    data
    |> Tuple.to_list()
    |> build_tuple_type_ir()
  end

  # --- HELPERS ---

  defp build_tuple_type_ir(data) do
    data = Enum.map(data, &transform/1)
    %IR.TupleType{data: data}
  end

  def debug({_module, _function, [ast] = _args}, result) do
    IO.puts("\nTRANSFORM...............................\n")
    IO.puts("ast")
    IO.inspect(ast)
    IO.puts("")
    IO.puts("result")
    IO.inspect(result)
    IO.puts("\n........................................\n")
  end

  defp transform_list(list) do
    list
    |> List.wrap()
    |> Enum.map(&transform/1)
  end
end
