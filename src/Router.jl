module RouterModule

using ..ConnModule
using ..PipelineModule
using HTTP

export Route, match_and_dispatch, @router, pipe_through, pipeline, scope

# --- Structs ---

struct Route
    method::String
    path_template::String
    regex::Regex
    param_names::Vector{Symbol}
    pipeline_names::Vector{Symbol}
    handler::Function
end

struct SuindaraRouter
    routes::Vector{Route}
    pipelines::Dict{Symbol, Vector{Any}}
end

# --- Dispatch ---

function match_and_dispatch(router::SuindaraRouter, req::HTTP.Request)
    return match_and_dispatch(router, Conn(req))
end

function match_and_dispatch(router::SuindaraRouter, conn::Conn)
    if conn.halted
        return conn
    end

    req = conn.request
    for route in router.routes
        if route.method == req.method
            m = match(route.regex, req.target)
            if m !== nothing
                for name in route.param_names
                    conn.params[string(name)] = m[name]
                end
                
                try
                    # Run pipelines first
                    # "plugs" here are functions/closures obtained at runtime
                    for pipe_name in route.pipeline_names
                        if haskey(router.pipelines, pipe_name)
                            plugs = router.pipelines[pipe_name]
                            conn = PipelineModule.run_pipeline(conn, plugs)
                            if conn.halted
                                return conn
                            end
                        else
                            @warn "Pipeline :$pipe_name not found in router"
                        end
                    end

                    return route.handler(conn)
                catch e
                    @error "Internal Server Error" exception=(e, catch_backtrace())
                    return resp(conn, 500, "Internal Server Error")
                end
            end
        end
    end
    return resp(conn, 404, "Route not found")
end

# --- Route Compilation ---

function compile_route(path::String)
    segments = split(path, "/")
    regex_parts = String[]
    param_names = Symbol[]
    
    for segment in segments
        if isempty(segment); continue; end
        
        if startswith(segment, ":")
            param_name = Symbol(segment[2:end])
            push!(param_names, param_name)
            push!(regex_parts, "/(?P<$param_name>[^/]+)")
        else
            push!(regex_parts, "/$segment")
        end
    end
    
    regex_str = isempty(regex_parts) ? "^/\$" : "^" * join(regex_parts) * "\$"
    return Regex(regex_str), param_names
end

# --- Macro logic (internal helpers) ---

mutable struct RouterState
    path_stack::Vector{String}
    pipeline_stack::Vector{Symbol}
    routes::Vector{Expr}
    pipelines::Dict{Symbol, Vector{Any}}
end

# Extract symbol from QuoteNode or Symbol
function extract_symbol(x)
    if x isa QuoteNode
        return x.value
    elseif x isa Symbol
        return x
    else
        return Symbol(x)
    end
end

function process_block!(state::RouterState, block::Expr)
    if block.head == :block
        for expr in block.args
            process_expr!(state, expr)
        end
    else
        process_expr!(state, block)
    end
end

function process_expr!(state::RouterState, expr::Any)
    if !(expr isa Expr); return; end

    # Handle `do` blocks (Expr(:do, call, func))
    if expr.head == :do
        call_expr = expr.args[1]
        func_expr = expr.args[2] # (args...) -> block

        if call_expr.head == :call
            func_name = call_expr.args[1]

            if func_name == :pipeline
                # pipeline(:name) do ... end
                name_sym = extract_symbol(call_expr.args[2])
                
                # func_expr.args[2] is the block
                block = func_expr.args[2]
                
                plugs = []
                if block isa Expr && block.head == :block
                    for line in block.args
                        if !(line isa LineNumberNode)
                            push!(plugs, line)
                        end
                    end
                elseif block isa Expr || block isa Symbol
                     push!(plugs, block)
                end
                state.pipelines[name_sym] = plugs

            elseif func_name == :scope
                # scope("/path") do ... end
                path_part = call_expr.args[2]
                
                # func_expr.args[2] is the block
                block = func_expr.args[2]

                push!(state.path_stack, path_part)
                old_pipe_len = length(state.pipeline_stack)
                
                process_block!(state, block)
                
                pop!(state.path_stack)
                while length(state.pipeline_stack) > old_pipe_len
                    pop!(state.pipeline_stack)
                end
            end
        end
        return
    end

    if expr.head == :call
        func = expr.args[1]

        # Handle explicit block syntax: pipeline(:name, begin ... end) or scope("/path", begin ... end)
        if func == :pipeline && length(expr.args) >= 3
             name_sym = extract_symbol(expr.args[2])
             block = expr.args[3]
             plugs = []
             if block isa Expr && block.head == :block
                 for line in block.args
                     if !(line isa LineNumberNode); push!(plugs, line); end
                 end
             else
                 push!(plugs, block)
             end
             state.pipelines[name_sym] = plugs
             
        elseif func == :scope && length(expr.args) >= 3
             path_part = expr.args[2]
             block = expr.args[3]
             push!(state.path_stack, path_part)
             old_pipe_len = length(state.pipeline_stack)
             process_block!(state, block)
             pop!(state.path_stack)
             while length(state.pipeline_stack) > old_pipe_len; pop!(state.pipeline_stack); end

        elseif func == :pipe_through
            # pipe_through(:name) or pipe_through([:name1, :name2])
            arg = expr.args[2]
            if arg isa QuoteNode || arg isa Symbol
                push!(state.pipeline_stack, extract_symbol(arg))
            elseif arg isa Expr && arg.head == :vect
                for item in arg.args
                    if item isa QuoteNode || item isa Symbol
                        push!(state.pipeline_stack, extract_symbol(item))
                    end
                end
            end

        elseif func in [:get, :post, :put, :delete, :patch, :options, :head]
            method = string(func) |> uppercase
            path = expr.args[2]
            handler = expr.args[3]

            base_path = join(state.path_stack, "")
            full_path = base_path * path
            full_path = replace(full_path, "//" => "/")
            if length(full_path) > 1 && endswith(full_path, "/")
                 full_path = full_path[1:end-1]
            end

            current_pipes = copy(state.pipeline_stack)

            push!(state.routes, quote
                r, names = ($(@__MODULE__)).compile_route($full_path)
                Route($method, $full_path, r, names, $(current_pipes), $(esc(handler)))
            end)
        end
    end
end

"""
    @router Name begin ... end
"""
macro router(name, block)
    state = RouterState(String[], Symbol[], Expr[], Dict{Symbol, Vector{Any}}())
    process_block!(state, block)
    
    pipe_entries = Expr(:block)
    for (name_sym, plugs) in state.pipelines
        escaped_plugs = Expr(:vect, [esc(p) for p in plugs]...)
        push!(pipe_entries.args, :(d[$(QuoteNode(name_sym))] = $escaped_plugs)) 
    end

    quote
        $(esc(name)) = let
            d = Dict{Symbol, Vector{Any}}()
            $pipe_entries
            routes_vec = [$(state.routes...)]
            SuindaraRouter(routes_vec, d)
        end
    end
end

# Dummy functions
function pipeline(args...) end
function scope(args...) end
function pipe_through(args...) end

end # module