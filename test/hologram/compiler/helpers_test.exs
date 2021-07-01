defmodule Hologram.Compiler.HelpersTest do
  use Hologram.TestCase, async: true
  alias Hologram.Compiler.Helpers

  test "class_name/1" do
    assert Helpers.class_name([:Abc, :Bcd]) == "AbcBcd"
  end

  test "fully_qualified_module/1" do
    result = Helpers.fully_qualified_module([:Hologram, :Compiler, :HelpersTest])
    expected = Elixir.Hologram.Compiler.HelpersTest
    assert result == expected
  end

  test "module_name/1" do
    assert Helpers.module_name([:Abc, :Bcd]) == "Abc.Bcd"
  end

  test "module_name_atom/1" do
    assert Helpers.module_name_atom([:Abc, :Bcd]) == :"Abc.Bcd"
  end

  test "module_name_parts/1" do
    assert Helpers.module_name_parts(Abc.Bcd) == [:Abc, :Bcd]
  end

  test "module_source_path/1" do
    result = Helpers.module_source_path([:Hologram, :Compiler, :HelpersTest])
    expected = __ENV__.file

    assert result == expected
  end
end
