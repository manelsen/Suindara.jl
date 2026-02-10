module Suindara

include("Conn.jl")
include("Pipeline.jl")
include("Router.jl")

include("Changeset.jl")
include("Web.jl")
include("Repo.jl")
include("Generator.jl")

using .ConnModule
using .PipelineModule
using .RouterModule
using .ChangesetModule
using .WebModule
using .RepoModule
using .GeneratorModule

export Conn, assign, halt!, resp, run_pipeline
export Route, match_and_dispatch, @router
export Changeset, cast, validate_required
export plug_json_parser, render_json
export Repo
export generate_project

end # module