"""
# Suindara.jl

**Suindara** is a high-performance, functional web framework for Julia, inspired by Elixir's Phoenix.
It leverages Julia's multiple dispatch and metaprogramming capabilities to provide a robust,
secure, and efficient platform for building web applications.

## Key Features
- **Pipeline Architecture**: Requests flow through a series of "Plugs" (functions).
- **Phoenix-style Router**: Declarative routing with parameter extraction.
- **Changesets**: Ecto-inspired data validation and transformation.
- **Repo**: Thread-safe SQLite integration with SQL injection protection.

## Usage
Typically used by generating a new project via the CLI or creating a `Conn` pipeline manually.
"""
module Suindara

include("Conn.jl")
include("Pipeline.jl")
include("Router.jl")

include("Changeset.jl")
include("Web.jl")
include("RepoAdapter.jl")
include("adapters/SQLiteAdapter.jl")
include("Repo.jl")
include("Resource.jl")
include("Migration.jl")
include("Generator.jl")
include("HotReload.jl")
include("Cors.jl")
include("Logger.jl")
include("StaticFile.jl")
include("FormParser.jl")
include("QueryBuilder.jl")
include("Association.jl")
include("TestHelpers.jl")
include("ErrorHandler.jl")
include("Channel.jl")
include("OpenAPI.jl")
include("Auth.jl")
include("RateLimiter.jl")
include("Telemetry.jl")
include("Template.jl")
include("Session.jl")
include("CSRF.jl")
include("Socket.jl")
include("Server.jl")
include("BenchmarkSuite.jl")

using .ConnModule
using .PipelineModule
using .RouterModule
using .ChangesetModule
using .WebModule
using .RepoAdapterModule
using .Repo
using .ResourceModule
using .MigrationModule
using .GeneratorModule
using .HotReloadModule
using .CorsModule
using .LoggerModule
using .StaticFileModule
using .FormParserModule
using .QueryBuilderModule
using .AssociationModule
using .TestHelpersModule
using .ErrorHandlerModule
using .ChannelModule
using .OpenAPIModule
using .AuthModule
using .RateLimiterModule
using .TelemetryModule
using .TemplateModule
using .SessionModule
using .CSRFModule
using .SocketModule
using .ServerModule
using .BenchmarkSuite

export Conn, assign, halt!, resp, run_pipeline, json, text, html, status, put_header
export Route, match_and_dispatch, @router
export Changeset, cast, validate_required, validate_format, validate_length, validate_inclusion
export plug_json_parser, render_json
export Repo
export ResourceController
export MigrationModule, migrate, rollback, create_table, add_column, drop_table
export generate_project, generate_migration
export revise_available, start_watching
export plug_cors, make_cors_plug
export plug_request_id, format_log_line
export make_static_plug
export plug_form_parser
export from, where, select, qb_limit, qb_offset, order_by, to_sql, qb_all, Query
export preload_has_many, preload_belongs_to
export build_conn, assert_status, assert_body_contains, setup_test_db
export format_error, is_dev_mode
export ChannelRegistry, register_handler!, dispatch_event
export generate_spec, spec_to_json
export make_bearer_plug
export make_rate_limit_plug
export TelemetryStore, attach!, emit, measure_latency
export render_string, render_file, escape_html, plug_render_html
export MemorySessionStore, make_session_plug, session_get, session_put!, session_delete!
export make_csrf_plug
export AbstractAdapter, create_adapter, convert_placeholders
export Socket, handle_socket, handle_stream

end # module