defmodule Hologram.Socket.Decoder do
  alias Hologram.Commons.IntegerUtils

  @doc """
  Decodes a term serialized by the client and pre-decoded from JSON.
  """
  @spec decode(map | String.t()) :: any
  def decode(term)

  def decode(%{"type" => "atom", "value" => value}) do
    String.to_existing_atom(value)
  end

  def decode("__integer__:" <> value) do
    IntegerUtils.parse!(value)
  end
end
