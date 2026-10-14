# Styx

<p align="center">
  Robust job processing in Elixir, backed by modern PostgreSQL, MySQL, and SQLite3.
  Reliable, <br /> observable, and loaded with enterprise grade features.
</p>

<p align="center">
  <a href="https://hex.pm/packages/styx">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/styx.svg">
  </a>

  <a href="https://hexdocs.pm/styx">
    <img alt="Hex Docs" src="https://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a>

  <a href="https://github.com/gsmlg-dev/styx/actions">
    <img alt="CI Status" src="https://github.com/gsmlg-dev/styx/workflows/ci/badge.svg">
  </a>

  <a href="https://opensource.org/licenses/Apache-2.0">
    <img alt="Apache 2 License" src="https://img.shields.io/hexpm/l/styx">
  </a>
</p>

## Table of Contents

- [Features](#features)
- [Engines](#engines)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Getting Started](#quick-getting-started)
- [Learning](#learning)
- [Provenance](#provenance)
- [Contributing](#contributing)

---

<!-- MDOC -->

## Features

Styx's primary goals are **reliability**, **consistency** and **observability**.

Styx is a powerful and flexible library that can handle a wide range of background job use cases,
and it is well-suited for systems of any size. It provides a simple and consistent API for
scheduling and performing jobs, and it is built to be fault-tolerant and easy to monitor.

Styx is fundamentally different from other background job processing tools because _it retains job
data for historic metrics and inspection_. You can leave your application running indefinitely
without worrying about jobs being lost or orphaned due to crashes.

#### Advantages Over Other Tools

- **Fewer Dependencies** — If you are running a web app there is a _very good_ chance that you're
  running on top of a SQL database. Running your job queue within a SQL database minimizes system
  dependencies and simplifies data backups.

- **Transactional Control** — Enqueue a job along with other database changes, ensuring that
  everything is committed or rolled back atomically.

- **Database Backups** — Jobs are stored inside of your primary database, which means they are
  backed up together with the data that they relate to.

#### Advanced Features

- **Isolated Queues** — Jobs are stored in a single table but are executed in distinct queues.
  Each queue runs in isolation, with its own concurrency limits, ensuring that a job in a single
  slow queue can't back up other faster queues.

- **Isolated Jobs** — Every job runs in a dedicated process to provide fully concurrent execution,
  a clean environment between jobs, and efficient cleanup after the job runs.

- **Queue Control** — Queues can be started, stopped, paused, resumed and scaled independently at
  runtime locally or across _all_ running nodes (even in environments like Heroku, without
  distributed Erlang).

- **Resilient Queues** — Failing queries won't crash the entire supervision tree, instead a
  backoff mechanism will safely retry them again in the future.

- **Job Canceling** — Jobs can be canceled in the middle of execution regardless of which node
  they are running on. This stops the job at once and flags it as `cancelled`.

- **Triggered Execution** — Insert triggers ensure that jobs are dispatched on all connected nodes
  as soon as they are inserted into the database.

- **Unique Jobs** — Duplicate work can be avoided through unique job controls. Uniqueness can be
  enforced at the argument, queue, worker and even sub-argument level for any period of time.

- **Scheduled Jobs** — Jobs can be scheduled at any time in the future, down to the second.

- **Periodic (CRON) Jobs** — Automatically enqueue jobs on a cron-like schedule. Duplicate jobs
  are never enqueued, no matter how many nodes you're running.

- **Job Priority** — Prioritize jobs within a queue to run ahead of others with ten levels of
  granularity.

- **Historic Metrics** — After a job is processed the row isn't deleted. Instead, the job is
  retained in the database to provide metrics. This allows users to inspect historic jobs and to
  see aggregate data at the job, queue or argument level.

- **Node Metrics** — Every queue records metrics to the database during runtime. These are used to
  monitor queue health across nodes and may be used for analytics.

- **Graceful Shutdown** — Queue shutdown is delayed so that slow jobs can finish executing before
  shutdown. When shutdown starts queues are paused and stop executing new jobs. Any jobs left
  running after the shutdown grace period may be rescued later.

- **Telemetry Integration** — Job life-cycle events are emitted via [Telemetry][tele] integration.
  This enables simple logging, error reporting and health checkups without plug-ins.

[tele]: https://github.com/beam-telemetry/telemetry

## Engines

Styx ships with engines for [PostgreSQL][postgres], [MySQL][mysql], and [SQLite3][sqlite3]. Each
engine supports the same core functionality, though they have differing levels of maturity and
suitability for production.

[postgres]: https://www.postgresql.org/
[mysql]: https://www.mysql.com/
[sqlite3]: https://www.sqlite.org/

## Requirements

Styx requires:

* Elixir 1.18+
* Erlang 25+
* PostgreSQL 14.0+, MySQL 8.4+, or SQLite3 3.37.0+

## Installation

See the [installation guide](guides/introduction/installation.md) for details on installing
and configuring Styx in your application.

## Quick Getting Started

  1. Configure queues and an Ecto repo for Styx to use:

     ```elixir
     # In config/config.exs
     config :my_app, Styx,
       repo: MyApp.Repo,
       queues: [mailers: 20]
     ```

  2. Define a worker to process jobs in the `mailers` queue (see `Styx.Worker`):

     ```elixir
     defmodule MyApp.MailerWorker do
       use Styx.Worker, queue: :mailers

       @impl Styx.Worker
       def perform(%Styx.Job{args: %{"email" => email} = _args}) do
         _ = Email.deliver(email)
         :ok
       end
     end
     ```

  3. Enqueue a job (see `Styx.Job`):

     ```elixir
     %{email: %{to: "foo@example.com", body: "Hello from Styx!"}}
     |> MyApp.MailerWorker.new()
     |> Styx.insert()
     ```

  4. Styx executes the job when there is available bandwidth in the `mailers` queue.

## Learning

Refer to the included guides in `guides/` for topics covering defining queues, job lifecycle,
scheduling, unique jobs, testing, and operational maintenance.

<!-- MDOC -->

## Provenance

Styx is derived from [Oban](https://github.com/oban-bg/oban), originally created by Parker Selbert.
Styx is an independent open-source project and is not affiliated with, endorsed by, or sponsored by
Sorensen Selbert LLC or the upstream Oban project.

## Contributing

To run the Styx test suite you must have PostgreSQL 14+ and MySQL 8+ running. Follow these steps
to create the database and run all migrations:

```bash
mix test.setup
```

To ensure a commit passes CI you should run `mix test.ci` locally, which executes the following
commands:

* Check formatting (`mix format --check-formatted`)
* Check deps (`mix deps.unlock --check-unused`)
* Lint with Credo (`mix credo --strict`)
* Run all tests (`mix test --raise`)
* Run Dialyzer (`mix dialyzer`)
