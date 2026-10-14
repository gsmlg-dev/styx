defmodule Styx.Plugins.Reindexer do
  @moduledoc """
  Deprecated, use `Styx.Reindexer` instead.
  """

  @doc false
  @deprecated "Use Styx.Reindexer instead"
  defdelegate child_spec(opts), to: Styx.Reindexer

  @doc false
  @deprecated "Use Styx.Reindexer instead"
  defdelegate start_link(opts), to: Styx.Reindexer

  @doc false
  @deprecated "Use Styx.Reindexer instead"
  defdelegate init(state), to: Styx.Reindexer

  @doc false
  @deprecated "Use Styx.Reindexer instead"
  defdelegate validate(opts), to: Styx.Reindexer
end
