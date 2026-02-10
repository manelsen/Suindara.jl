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
include("Repo.jl")
include("Resource.jl")
include("Migration.jl")
include("Generator.jl")

using .ConnModule
using .PipelineModule
using .RouterModule
using .ChangesetModule
using .WebModule
using .Repo
using .ResourceModule
using .MigrationModule
using .GeneratorModule

export Conn, assign, halt!, resp, run_pipeline
export Route, match_and_dispatch, @router
export Changeset, cast, validate_required
export plug_json_parser, render_json
export Repo
export ResourceController
export MigrationModule, migrate, rollback, create_table, add_column, drop_table # Export migration tools
export generate_project, generate_migration

end # module