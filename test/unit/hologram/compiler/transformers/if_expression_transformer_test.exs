defmodule Hologram.Compiler.IfExpressionTransformerTest do
  use Hologram.Test.UnitCase, async: true

  alias Hologram.Compiler.{Context, IfExpressionTransformer}
  alias Hologram.Compiler.IR.{Block, BooleanType, IfExpression, IntegerType, NilType}

  test "do clause with single expression" do
    code = "if true, do: 1"
    ast = ast(code)
    result = IfExpressionTransformer.transform(ast, %Context{})

    expected = %IfExpression{
      condition: %BooleanType{value: true},
      do: %Block{expressions: [%IntegerType{value: 1}]},
      else: %Block{expressions: [%NilType{}]},
      ast: ast
    }

    assert result == expected
  end

  test "do clause with multiple expressions" do
    code = """
    if true do
      1
      2
    end
    """

    ast = ast(code)
    result = IfExpressionTransformer.transform(ast, %Context{})

    expected = %IfExpression{
      condition: %BooleanType{value: true},
      do: %Block{expressions: [
          %IntegerType{value: 1},
          %IntegerType{value: 2}
        ]
      },
      else: %Block{expressions: [%NilType{}]},
      ast: ast
    }

    assert result == expected
  end

  test "do clause with single expression and else clause with single expression" do
    code = "if true, do: 1, else: 2"
    ast = ast(code)
    result = IfExpressionTransformer.transform(ast, %Context{})

    expected = %IfExpression{
      condition: %BooleanType{value: true},
      do: %Block{expressions: [%IntegerType{value: 1}]},
      else: %Block{expressions: [%IntegerType{value: 2}]},
      ast: ast
    }

    assert result == expected
  end

  test "do clause with multiple expressions and else clause with single expression" do
    code = """
    if true do
      1
      2
    else
      3
    end
    """

    ast = ast(code)
    result = IfExpressionTransformer.transform(ast, %Context{})

    expected = %IfExpression{
      condition: %BooleanType{value: true},
      do: %Block{expressions: [
        %IntegerType{value: 1},
        %IntegerType{value: 2}
      ]},
      else: %Block{expressions: [%IntegerType{value: 3}]},
      ast: ast
    }

    assert result == expected
  end

  test "do clause with multiple expressions and else clause with multiple expressions" do
    code = """
    if true do
      1
      2
    else
      3
      4
    end
    """

    ast = ast(code)
    result = IfExpressionTransformer.transform(ast, %Context{})

    expected = %IfExpression{
      condition: %BooleanType{value: true},
      do: %Block{expressions: [
        %IntegerType{value: 1},
        %IntegerType{value: 2}
      ]},
      else: %Block{expressions: [
        %IntegerType{value: 3},
        %IntegerType{value: 4}
      ]},
      ast: ast
    }

    assert result == expected
  end
end
