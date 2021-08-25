defmodule Hologram.Compiler.HelpersTest do
  use Hologram.TestCase, async: true

  alias Hologram.Compiler.Helpers
  alias Hologram.Compiler.IR.{ModuleDefinition, UseDirective}

  test "class_name/1" do
    assert Helpers.class_name(Abc.Bcd) == "Elixir_Abc_Bcd"
  end

  describe "fetch_block_body/1" do
    test "block" do
      ast = {:__block__, [], [1, 2]}
      result = Helpers.fetch_block_body(ast)

      assert result == [1, 2]
    end

    test "non-block" do
      ast = 1
      result = Helpers.fetch_block_body(ast)

      assert result == [1]
    end
  end

  test "get_components/1" do
    module_def_1 =
      %ModuleDefinition{
        module: Bcd.Cde,
        uses: [
          %UseDirective{module: Hologram.Component}
        ]
      }

    module_def_2 =
      %ModuleDefinition{
        module: Def.Efg,
        uses: [
          %UseDirective{module: Hologram.Component}
        ]
      }

    module_defs_map = %{
      Abc.Bcd => %ModuleDefinition{uses: []},
      Bcd.Cde => module_def_1,
      Cde.Def => %ModuleDefinition{uses: []},
      Def.Efg => module_def_2
    }

    result = Helpers.get_components(module_defs_map)
    expected = [module_def_1, module_def_2]

    assert result == expected
  end

  test "get_pages/1" do
    module_def_1 =
      %ModuleDefinition{
        module: Bcd.Cde,
        uses: [
          %UseDirective{module: Hologram.Page}
        ]
      }

    module_def_2 =
      %ModuleDefinition{
        module: Def.Efg,
        uses: [
          %UseDirective{module: Hologram.Page}
        ]
      }

    module_defs_map = %{
      Abc.Bcd => %ModuleDefinition{uses: []},
      Bcd.Cde => module_def_1,
      Cde.Def => %ModuleDefinition{uses: []},
      Def.Efg => module_def_2
    }

    result = Helpers.get_pages(module_defs_map)
    expected = [module_def_1, module_def_2]

    assert result == expected
  end

  describe "is_component?/1" do
    test "true" do
      module_definition = %ModuleDefinition{
        uses: [
          %UseDirective{
            module: Hologram.Component
          }
        ]
      }

      assert Helpers.is_component?(module_definition)
    end

    test "false" do
      module_definition = %ModuleDefinition{uses: []}
      refute Helpers.is_component?(module_definition)
    end
  end

  describe "is_page?/1" do
    test "true" do
      module_definition = %ModuleDefinition{
        uses: [
          %UseDirective{
            module: Hologram.Page
          }
        ]
      }

      assert Helpers.is_page?(module_definition)
    end

    test "false" do
      module_definition = %ModuleDefinition{uses: []}
      refute Helpers.is_page?(module_definition)
    end
  end

  test "module/1" do
    result = Helpers.module([:Hologram, :Compiler, :HelpersTest])
    expected = Elixir.Hologram.Compiler.HelpersTest
    assert result == expected
  end

  test "module_name/1" do
    assert Helpers.module_name(Abc.Bcd) == "Abc.Bcd"
  end

  describe "module_segments/1" do
    test "module" do
      assert Helpers.module_segments(Abc.Bcd) == [:Abc, :Bcd]
    end

    test "string" do
      assert Helpers.module_segments("Abc.Bcd") == [:Abc, :Bcd]
    end
  end

  describe "uses_module?/2" do
    @used_module Hologram.Commons.Parser

    test "true" do
      user_module = %ModuleDefinition{
        uses: [
          %UseDirective{
            module: @used_module
          }
        ]
      }

      assert Helpers.uses_module?(user_module, @used_module)
    end

    test "false" do
      user_module = %ModuleDefinition{uses: []}
      refute Helpers.uses_module?(user_module, @used_module)
    end
  end
end
