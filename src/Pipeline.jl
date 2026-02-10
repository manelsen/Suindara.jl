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
