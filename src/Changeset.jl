module ChangesetModule

export Changeset, cast, validate_required, validate_format, validate_length, validate_inclusion

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

"""
    validate_format(ch::Changeset, field::Symbol, pattern::Regex) :: Changeset

Valida que o valor do campo corresponde ao padrão regex.
Ignora o campo se ele não está presente nos changes.
"""
function validate_format(ch::Changeset, field::Symbol, pattern::Regex)::Changeset
    if !haskey(ch.changes, field)
        return ch
    end
    value = string(ch.changes[field])
    if !occursin(pattern, value)
        push_error!(ch, field, "has invalid format")
    end
    return ch
end

"""
    validate_length(ch::Changeset, field::Symbol; min, max) :: Changeset

Valida que o comprimento da string está entre min e max (inclusive).
"""
function validate_length(ch::Changeset, field::Symbol; min::Int=0, max::Int=typemax(Int))::Changeset
    if !haskey(ch.changes, field)
        return ch
    end
    len = length(ch.changes[field] isa AbstractString ? ch.changes[field] : string(ch.changes[field]))
    if len < min
        push_error!(ch, field, "should be at least $min character(s)")
    elseif len > max
        push_error!(ch, field, "should be at most $max character(s)")
    end
    return ch
end

"""
    validate_inclusion(ch::Changeset, field::Symbol, allowed::Vector) :: Changeset

Valida que o valor do campo está na lista de valores permitidos.
"""
function validate_inclusion(ch::Changeset, field::Symbol, allowed::Vector)::Changeset
    if !haskey(ch.changes, field)
        return ch
    end
    if !(ch.changes[field] in allowed)
        push_error!(ch, field, "is not included in the list of allowed values (inclusion)")
    end
    return ch
end

end # module
