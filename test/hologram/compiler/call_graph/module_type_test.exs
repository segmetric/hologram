defmodule Hologram.Compiler.CallGraph.ModuleTypeTest do
  use Hologram.Test.UnitCase, async: true

  alias Hologram.Compiler.CallGraph
  alias Hologram.Compiler.IR.ModuleType
  alias Hologram.Test.Fixtures.{PlaceholderModule1, PlaceholderModule2}

  test "non-standard lib module" do
    ir = %ModuleType{module: PlaceholderModule2}
    call_graph = Graph.new()
    from_vertex = PlaceholderModule1

    result = CallGraph.build(ir, call_graph, %{}, from_vertex)

    assert Graph.num_vertices(result) == 2
    assert Graph.num_edges(result) == 1
    assert has_edge?(result, PlaceholderModule1, PlaceholderModule2)
  end

  test "standard lib module" do
    ir = %ModuleType{module: Kernel}
    call_graph = Graph.new()
    from_vertex = PlaceholderModule1

    result = CallGraph.build(ir, call_graph, %{}, from_vertex)

    assert Graph.num_vertices(result) == 0
  end
end
