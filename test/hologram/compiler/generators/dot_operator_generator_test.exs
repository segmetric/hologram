defmodule Hologram.Compiler.DotOperatorGeneratorTest do
  use Hologram.TestCase, async: true

  alias Hologram.Compiler.{Context, DotOperatorGenerator, Opts}
  alias Hologram.Compiler.IR.{AtomType, Variable}

  test "generate/2" do
    left = %Variable{name: :x}
    right = %AtomType{value: :a}

    result = DotOperatorGenerator.generate(left, right, %Context{}, %Opts{})
    expected = "Elixir_Kernel.$dot(x, { type: 'atom', value: 'a' })"

    assert result == expected
  end
end
