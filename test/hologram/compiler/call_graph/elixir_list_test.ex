defmodule Hologram.Compiler.CallGraph.ElixirListTest do
  use Hologram.Test.UnitCase, async: true

  alias Hologram.Compiler.CallGraph
  alias Hologram.Compiler.IR.ModuleType
  alias Hologram.Test.Fixtures.PlaceholderModule1
  alias Hologram.Test.Fixtures.PlaceholderModule2
  alias Hologram.Test.Fixtures.PlaceholderModule3

  test "build/4" do
    ir = [
      %ModuleType{module: PlaceholderModule2},
      %ModuleType{module: PlaceholderModule3}
    ]

    call_graph = Graph.new()
    from_vertex = PlaceholderModule1

    result = CallGraph.build(ir, call_graph, %{}, from_vertex)

    assert Graph.num_vertices(result) == 3
    assert Graph.num_edges(result) == 2
    assert has_edge?(result, PlaceholderModule1, PlaceholderModule2)
    assert has_edge?(result, PlaceholderModule1, PlaceholderModule3)
  end
end
