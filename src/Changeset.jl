module ChangesetModule

export Changeset, cast, validate_required

mutable struct Changeset
    params::Dict{String, Any}
    changes::Dict{Symbol, Any}
    errors::Dict{Symbol, Vector{String}}
    valid::Bool
end

"""
    cast(params::Dict{String, Any}, allowed::Vector{Symbol})
Creates a changeset by filtering `params` against `allowed` keys.
"""
function cast(params::Dict, allowed::Vector{Symbol})
    # Convert input params to uniform Dict{String, Any} for storage
    uniform_params = Dict{String, Any}(string(k) => v for (k, v) in params)
    changes = Dict{Symbol, Any}()
    
    for key in allowed
        str_key = String(key)
        if haskey(uniform_params, str_key)
            changes[key] = uniform_params[str_key]
        end
    end
    
    return Changeset(uniform_params, changes, Dict{Symbol, Vector{String}}(), true)
end

"""
    validate_required(ch::Changeset, fields::Vector{Symbol})
Checks if the required fields are present in the changes.
"""
function validate_required(ch::Changeset, fields::Vector{Symbol})
    for field in fields
        if !haskey(ch.changes, field) || ch.changes[field] === nothing || ch.changes[field] == ""
            push_error!(ch, field, "can't be blank")
        end
    end
    return ch
end

function push_error!(ch::Changeset, field::Symbol, message::String)
    ch.valid = false
    if !haskey(ch.errors, field)
        ch.errors[field] = String[]
    end
    push!(ch.errors[field], message)
end

end # module