module ChangesetModule

export Changeset, cast, validate_required

"""
    mutable struct Changeset

Tracks changes, validations, and errors for data transformation.

# Fields
- `params::Dict{String, Any}`: The original input parameters (keys are strings).
- `changes::Dict{Symbol, Any}`: The filtered and casted changes to be applied.
- `errors::Dict{Symbol, Vector{String}}`: Validation errors keyed by field.
- `valid::Bool`: Indicates if the changeset has no errors.
"""
mutable struct Changeset
    params::Dict{String, Any}
    changes::Dict{Symbol, Any}
    errors::Dict{Symbol, Vector{String}}
    valid::Bool
end

"""
    cast(params::Dict, allowed::Vector{Symbol})

Creates a changeset from a dictionary of parameters, filtering only `allowed` keys.
Converts keys to Symbols for internal usage.

# Arguments
- `params`: Input dictionary (usually from JSON or form data).
- `allowed`: List of symbols allowed to be cast.

# Returns
A new `Changeset`.
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

Validates that the specified `fields` are present in the changes and are not null/empty.
Adds an error to the changeset if validation fails.
"""
function validate_required(ch::Changeset, fields::Vector{Symbol})
    for field in fields
        if !haskey(ch.changes, field) || ch.changes[field] === nothing || ch.changes[field] == ""
            push_error!(ch, field, "can't be blank")
        end
    end
    return ch
end

"""
    push_error!(ch::Changeset, field::Symbol, message::String)

Internal helper to add an error message to a specific field in the changeset.
Sets `valid` to `false`.
"""
function push_error!(ch::Changeset, field::Symbol, message::String)
    ch.valid = false
    if !haskey(ch.errors, field)
        ch.errors[field] = String[]
    end
    push!(ch.errors[field], message)
end

end # module
