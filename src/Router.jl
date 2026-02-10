module RouterModule

using ..ConnModule
using ..PipelineModule
using HTTP

export Route, match_and_dispatch, @router

struct Route
    method::String
    path_template::String
    regex::Regex
    param_names::Vector{Symbol}
    handler::Function
end

struct SuindaraRouter
    routes::Vector{Route}
end

function match_and_dispatch(router::SuindaraRouter, req::HTTP.Request)
    conn = Conn(req)
    for route in router.routes
        if route.method == req.method
            m = match(route.regex, req.target)
            if m !== nothing
                # Extract params from regex match
                for name in route.param_names
                    conn.params[name] = m[name]
                end
                
                try
                    return route.handler(conn)
                catch e
                    # Basic error handling for production readiness
                    return resp(conn, 500, "Internal Server Error: $(e)")
                end
            end
        end
    end
    return resp(conn, 404, "Route not found")
end

function compile_route(path::String)
    # Convert /users/:id to regex ^/users/(?P<id>[^/]+)$
    
    # 1. Escape special regex characters in the path, except for our colon
    # simplified approach: split by slash
    segments = split(path, "/")
    regex_parts = String[]
    param_names = Symbol[]
    
    for segment in segments
        if isempty(segment)
            continue
        end
        
        if startswith(segment, ":")
            param_name = Symbol(segment[2:end])
            push!(param_names, param_name)
            push!(regex_parts, "/(?P<$param_name>[^/]+)")
        else
            push!(regex_parts, "/$segment")
        end
    end
    
    # Handle root path
    if isempty(regex_parts)
        regex_str = "^/\$"
    else
        regex_str = "^" * join(regex_parts) * "\$"
    end
    
    return Regex(regex_str), param_names
end

macro router(name, block)
    route_exprs = []
    if block.head == :block
        for line in block.args
            if line isa Expr && line.head == :call
                method = string(line.args[1]) |> uppercase
                path = line.args[2]
                handler = line.args[3]
                
                # We need to compute regex at macro expansion time or runtime?
                # Doing it at runtime inside the constructor is easier for the macro.
                
                push!(route_exprs, quote
                    r, names = ($(@__MODULE__)).compile_route($path)
                    Route($method, $path, r, names, $(esc(handler)))
                end)
            end
        end
    end

    quote
        $(esc(name)) = SuindaraRouter([$(route_exprs...)])
    end
end

end # module
