defmodule Styx.Plugins.Pruner do
  @moduledoc """
  Deprecated, use `Styx.Pruner` instead.
  """

  @doc false
  @deprecated "Use Styx.Pruner instead"
  defdelegate child_spec(opts), to: Styx.Pruner

  @doc false
  @deprecated "Use Styx.Pruner instead"
  defdelegate start_link(opts), to: Styx.Pruner

  @doc false
  @deprecated "Use Styx.Pruner instead"
  defdelegate init(state), to: Styx.Pruner

  @doc false
  @deprecated "Use Styx.Pruner instead"
  defdelegate validate(opts), to: Styx.Pruner
end
