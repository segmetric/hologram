defmodule Hologram.Test.Fixtures.Compiler.ModuleDefAggregators.Component.Module1 do
  alias Hologram.Test.Fixtures.Compiler.ModuleDefAggregators.Component.Module2

  def test_fun_1a do
    Module2.test_fun_2a()
  end
end
