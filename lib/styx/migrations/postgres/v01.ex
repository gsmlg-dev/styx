defmodule Styx.Migrations.Postgres.V01 do
  @moduledoc false

  use Ecto.Migration

  def up(%{create_schema: create?, prefix: prefix, unlogged: unlogged?} = opts) do
    %{escaped_prefix: escaped, quoted_prefix: quoted} = opts

    if create?, do: execute("CREATE SCHEMA IF NOT EXISTS #{quoted}")

    execute """
    DO $$
    BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type
                   WHERE typname = 'styx_job_state'
                     AND typnamespace = '#{escaped}'::regnamespace::oid) THEN
        CREATE TYPE #{quoted}.styx_job_state AS ENUM (
          'available',
          'suspended',
          'scheduled',
          'executing',
          'retryable',
          'completed',
          'discarded',
          'cancelled'
        );
      END IF;
    END$$;
    """

    create_if_not_exists table(:styx_jobs, primary_key: false, prefix: prefix) do
      add :id, :bigserial, primary_key: true
      add :state, :"#{quoted}.styx_job_state", null: false, default: "available"
      add :queue, :text, null: false, default: "default"
      add :worker, :text, null: false
      add :args, :map, null: false, default: %{}
      add :meta, :map, null: false, default: %{}
      add :tags, {:array, :string}, null: false, default: []
      add :errors, {:array, :map}, null: false, default: []
      add :attempt, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false, default: 20
      add :priority, :integer, null: false, default: 0
      add :attempted_by, {:array, :string}, default: []

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("timezone('UTC', now())")

      add :scheduled_at, :utc_datetime_usec,
        null: false,
        default: fragment("timezone('UTC', now())")

      add :attempted_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :discarded_at, :utc_datetime_usec
    end

    create_if_not_exists index(:styx_jobs, [:state, :queue, :priority, :scheduled_at, :id],
                           prefix: prefix
                         )

    create_if_not_exists index(:styx_jobs, [:args], using: :gin, prefix: prefix)
    create_if_not_exists index(:styx_jobs, [:meta], using: :gin, prefix: prefix)

    create_if_not_exists index(:styx_jobs, [:state, :cancelled_at], prefix: prefix)
    create_if_not_exists index(:styx_jobs, [:state, :discarded_at], prefix: prefix)

    create constraint(:styx_jobs, :attempt_range,
             check: "attempt between 0 and max_attempts",
             prefix: prefix
           )

    create constraint(:styx_jobs, :positive_max_attempts,
             check: "max_attempts > 0",
             prefix: prefix
           )

    create constraint(:styx_jobs, :non_negative_priority,
             check: "priority >= 0",
             prefix: prefix
           )

    create constraint(:styx_jobs, :queue_length,
             check: "char_length(queue) > 0 AND char_length(queue) < 128",
             prefix: prefix
           )

    create constraint(:styx_jobs, :worker_length,
             check: "char_length(worker) > 0 AND char_length(worker) < 128",
             prefix: prefix
           )

    execute """
    CREATE OR REPLACE FUNCTION #{quoted}.styx_wrap_id(value bigint) RETURNS int AS $$
    BEGIN
      RETURN (value % 2147483647)::int;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """

    create_if_not_exists table(:styx_peers, primary_key: false, prefix: prefix) do
      add :name, :text, null: false, primary_key: true
      add :node, :text, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
    end

    if unlogged? do
      execute "ALTER TABLE #{quoted}.styx_peers SET UNLOGGED"
    end
  end

  def down(%{prefix: prefix, quoted_prefix: quoted}) do
    drop_if_exists table(:styx_peers, prefix: prefix)

    execute("DROP FUNCTION IF EXISTS #{quoted}.styx_wrap_id(value bigint)")

    drop_if_exists table(:styx_jobs, prefix: prefix)

    execute "DROP TYPE IF EXISTS #{quoted}.styx_job_state"
  end
end
