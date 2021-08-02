defmodule Hologram.Compiler.ModuleAttributeOperatorGenerator do
  alias Hologram.Compiler.{Context, Helpers, MapKeyGenerator, Opts}
  alias Hologram.Compiler.IR.AtomType

  def generate(name, %Context{} = context, %Opts{template: true}) do
    class_name = Helpers.class_name(context.module)
    "#{class_name}.$#{name}"
  end

  def generate(name, %Context{} = context, %Opts{} = opts) do
    key = MapKeyGenerator.generate(%AtomType{value: name}, context)
    "$state.data['#{key}']"
  end
end
