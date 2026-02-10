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
If `conn.halted` becomes true, execution stops immediately.
"""
function run_pipeline(conn::Conn, plugs::Vector{T}) where T <: Function
    for plug in plugs
        conn = plug(conn)
        if conn.halted
            break
        end
    end
    return conn
end

end # module
