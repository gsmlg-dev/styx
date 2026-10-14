defmodule Styx.Plugins.Cron do
  @moduledoc """
  Deprecated, use `Styx.Cron` instead.
  """

  @doc false
  @deprecated "Use Styx.Cron instead"
  defdelegate child_spec(opts), to: Styx.Cron

  @doc false
  @deprecated "Use Styx.Cron instead"
  defdelegate start_link(opts), to: Styx.Cron

  @doc false
  @deprecated "Use Styx.Cron instead"
  defdelegate init(state), to: Styx.Cron

  @doc false
  @deprecated "Use Styx.Cron instead"
  defdelegate validate(opts), to: Styx.Cron

  @doc false
  @deprecated "Use Styx.Cron instead"
  defdelegate parse(input), to: Styx.Cron

  @doc false
  @deprecated "Use Styx.Cron instead"
  defdelegate interval_to_next_minute(), to: Styx.Cron
end
