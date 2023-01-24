defmodule AppWeb.PageLive do
  @moduledoc """
  Page LiveView
  """

  use AppWeb, :live_view

  def render(assigns) do
    ~H"""
    <p>Hello, world</p>
    """
  end
end
