alias Hologram.Commons.Reflection
alias Hologram.Compiler

Benchee.run(
  %{
    "validate_page_modules/1" => fn page_modules ->
      Compiler.validate_page_modules(page_modules)
    end
  },
  before_scenario: fn _input ->
    Reflection.list_pages()
  end,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     description: "Compiler.validate_page_modules/1", file: Path.join(__DIR__, "README.md")}
  ],
  time: 60
)
