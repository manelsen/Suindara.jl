module RouterModule

using ..ConnModule
using ..PipelineModule
using HTTP

export Route, match_and_dispatch, @router

"""
    struct Route

Represents a single compiled route definition.

# Fields
- `method::String`: The HTTP method (e.g., "GET", "POST").
- `path_template::String`: The original path string (e.g., "/users/:id").
- `regex::Regex`: The compiled regular expression for matching the path.
- `param_names::Vector{Symbol}`: List of parameter names extracted from the path.
- `handler::Function`: The controller function to be executed if matched.
"""
struct Route
    method::String
    path_template::String
    regex::Regex
    param_names::Vector{Symbol}
    handler::Function
end

"""
    struct SuindaraRouter

A container for a collection of routes.
"""
struct SuindaraRouter
    routes::Vector{Route}
end

"""
    match_and_dispatch(router::SuindaraRouter, req::HTTP.Request)

Matches an incoming HTTP request against the defined routes.
If a match is found:
1. Creates a `Conn`.
2. Extracts path parameters into `conn.params`.
3. Executes the associated handler (controller).
4. Catches any unhandled exceptions, logging them and returning a generic 500 error.

Returns 404 if no route matches.
"""
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
                    # Log error to stderr and return generic 500
                    @error "Internal Server Error" exception=(e, catch_backtrace())
                    return resp(conn, 500, "Internal Server Error")
                end
            end
        end
    end
    return resp(conn, 404, "Route not found")
end

"""
    compile_route(path::String)

Compiles a path string (like `/users/:id`) into a regex and a list of parameter names.
Internal function used by the `@router` macro.
"""
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

"""
    @router name block

Macro to define a router with a DSL.

# Example
```julia
@router AppRouter begin
    get("/", PageController.index)
    get("/users/:id", UserController.show)
end
```
"""
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