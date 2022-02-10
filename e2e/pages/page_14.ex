defmodule Hologram.E2E.Page14 do
  use Hologram.Page

  route "/e2e/page-14"

  def init do
    %{
      left: 10,
      right: 6,
      result: 0
    }
  end

  def template do
    ~H"""
    <button id="button" on:click="calculate">Calculate</button>
    <div id="text">Result = {@result}</div>
    """
  end

  def action(:calculate, _params, state) do
    Map.put(state, :result, state.left - state.right)
  end
end
