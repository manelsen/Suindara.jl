"""
    module PipelineModule

Provides the core engine for executing a sequence of transformations on a `Conn`.

A "Plug" in Suindara is simply a function that takes a `Conn` as input and returns a `Conn` (modified or not).
If a plug calls `halt!(conn)`, the pipeline stops executing subsequent plugs.
"""
module PipelineModule

using ..ConnModule

export run_pipeline

"""
    run_pipeline(conn::Conn, plugs::Vector{T}) where T <: Function
Executes a sequence of plugs on a connection. 
Each plug MUST return the modified `Conn` object (Standard Pattern: In-place mutation).
If `conn.halted` becomes true, execution stops immediately.
"""
function run_pipeline(conn::Conn, plugs::Vector{T}) where T <: Function
    for plug in plugs
        try
            conn = plug(conn)
        catch e
            @error "Pipeline error" exception=(e, catch_backtrace())
            return halt!(conn, 500, "Internal Server Error")
        end
        
        if conn.halted
            break
        end
    end
    return conn
end

end # module
