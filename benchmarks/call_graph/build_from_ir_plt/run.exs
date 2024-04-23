alias Hologram.Compiler
alias Hologram.Compiler.CallGraph

Benchee.run(
  %{
    "build_from_ir_plt/1" => fn ir_plt ->
      CallGraph.build_from_ir_plt(ir_plt)
    end
  },
  before_scenario: fn _input ->
    Compiler.build_ir_plt(Compiler.build_module_beam_path_plt())
  end,
  after_each: fn call_graph ->
    CallGraph.stop(call_graph)
  end,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     description: "build_from_ir_plt/1", file: Path.join(__DIR__, "README.md")}
  ],
  time: 60
)
