defmodule Styx.Plugins.Lifeline do
  @moduledoc """
  Deprecated, use `Styx.Lifeline` instead.
  """

  @doc false
  @deprecated "Use Styx.Lifeline instead"
  defdelegate child_spec(opts), to: Styx.Lifeline

  @doc false
  @deprecated "Use Styx.Lifeline instead"
  defdelegate start_link(opts), to: Styx.Lifeline

  @doc false
  @deprecated "Use Styx.Lifeline instead"
  defdelegate init(state), to: Styx.Lifeline

  @doc false
  @deprecated "Use Styx.Lifeline instead"
  defdelegate validate(opts), to: Styx.Lifeline
end
