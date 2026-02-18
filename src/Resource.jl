"""
    module ResourceModule

Provides a generic "Resource" controller implementation (similar to Django REST Framework's ViewSets).
It allows generating full CRUD APIs for any struct/model with zero boilerplate using Multiple Dispatch.

# Usage
1. Define your struct: `struct User ... end`
2. Define schema: `Resource.schema(::Type{User}) = [:name, :email]`
3. Define table: `Resource.table_name(::Type{User}) = "users"`
4. Use in Router: `post("/users", conn -> ResourceController.create(conn, User))`
"""
module ResourceModule

using ..ConnModule
using ..Repo
using ..ChangesetModule
using ..WebModule

export ResourceController, schema, table_name, primary_key, @schema

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 100

# --- Interface (User Overrides) ---

"""
    schema(::Type{T})
Should return a Vector{Symbol} of allowed fields for mass assignment (create/update).
"""
function schema end

"""
    table_name(::Type{T})
Should return the database table name (String) for the entity.
"""
function table_name end

"""
    primary_key(::Type{T})
Returns the primary key column name. Defaults to :id.
"""
function primary_key(::Type{T}) where T
    return :id
end

# --- Generic Controller Implementation ---

module ResourceController
    using ..ResourceModule
    using ..ConnModule
    using ..Repo
    using ..ChangesetModule
    using ..WebModule

    """
    index(conn::Conn, ::Type{T})
    Lists all records for entity T.
    """
    function index(conn::Conn, ::Type{T}) where T
        table = ResourceModule.table_name(T)
        
        # Pagination
        limit_str = get(conn.params, "limit", string(ResourceModule.DEFAULT_LIMIT))
        offset_str = get(conn.params, "offset", "0")
        
        limit = tryparse(Int, limit_str)
        offset = tryparse(Int, offset_str)
        
        limit = (limit === nothing) ? ResourceModule.DEFAULT_LIMIT : limit
        offset = (offset === nothing) ? 0 : offset
        
        # Hard cap for security
        limit = clamp(limit, 0, ResourceModule.MAX_LIMIT)
        
        results = Repo.query("SELECT * FROM $table LIMIT $limit OFFSET $offset")
        
        # Convert SQLite rows to simple Dicts for JSON serialization
        # (JSON3 handles named tuples well, but explicit is good)
        data = [NamedTuple(Symbol(k) => getproperty(row, Symbol(k)) for k in propertynames(row)) for row in results]
        return render_json(conn, data)
    end

    """
    show(conn::Conn, ::Type{T})
    Shows a single record by ID.
    """
    function show(conn::Conn, ::Type{T}) where T
        id = conn.params["id"]
        table = ResourceModule.table_name(T)
        pk = String(ResourceModule.primary_key(T))
        
        row = Repo.get_one(table, id, pk=pk)
        
        if row === nothing
            return halt!(conn, 404, "Resource not found")
        end
        
        return render_json(conn, row)
    end

    """
    create(conn::Conn, ::Type{T})
    Creates a new record.
    """
    function create(conn::Conn, ::Type{T}) where T
        allowed = ResourceModule.schema(T)
        ch = cast(conn.params, allowed)
        ch = validate_required(ch, allowed) # By default require all schema fields? Or let user define?
        
        # For a generic controller, strict validation is safer.
        
        if !ch.valid
            return render_json(conn, ch.errors, status=422)
        end
        
        table = ResourceModule.table_name(T)
        
        try
            Repo.insert(ch, table)
            return render_json(conn, ch.changes, status=201)
        catch e
            # Log error
            return halt!(conn, 500, "Database Error")
        end
    end

    """
    update(conn::Conn, ::Type{T})
    Updates an existing record.
    """
    function update(conn::Conn, ::Type{T}) where T
        id = conn.params["id"]
        table = ResourceModule.table_name(T)
        pk = String(ResourceModule.primary_key(T))
        
        # Check existence first
        existing = Repo.get_one(table, id, pk=pk)
        if existing === nothing
            return halt!(conn, 404, "Resource not found")
        end
        
        allowed = ResourceModule.schema(T)
        ch = cast(conn.params, allowed)
        
        if !ch.valid
            return render_json(conn, ch.errors, status=422)
        end
        
        try
            Repo.update(ch, table, id, pk=pk)
            return render_json(conn, ch.changes)
        catch e
            return halt!(conn, 500, "Database Error")
        end
    end

    """
    delete(conn::Conn, ::Type{T})
    Deletes a record.
    """
    function delete(conn::Conn, ::Type{T}) where T
        id = conn.params["id"]
        table = ResourceModule.table_name(T)
        pk = String(ResourceModule.primary_key(T))
        
        existing = Repo.get_one(table, id, pk=pk)
        if existing === nothing
            return halt!(conn, 404, "Resource not found")
        end
        
        try
            Repo.delete(table, id, pk=pk)
            return resp(conn, 204, "") # No Content
        catch e
            return halt!(conn, 500, "Database Error")
        end
    end

end # module ResourceController

"""
    @schema Name table_name block

Macro to define a model struct and its database metadata in one go.

# Example
```julia
@schema User "users" begin
    field :name, String
    field :email, String
end
```
"""
macro schema(name, table, block)
    fields = []
    schema_fields = Symbol[]
    
    # Always include id
    push!(fields, :(id::Union{Int, Nothing}))
    
    function extract_sym(x)
        if x isa Symbol; return x; end
        if x isa QuoteNode; return x.value; end
        if x isa Expr && x.head == :quote; return x.args[1]; end
        return nothing
    end

    if block.head == :block
        for line in block.args
            if line isa LineNumberNode; continue; end
            
            if line isa Expr && line.head == :call
                func = line.args[1]
                if func == :field
                    field_name = extract_sym(line.args[2])
                    field_type = line.args[3]
                    
                    if field_name !== nothing
                        push!(schema_fields, field_name)
                        push!(fields, :($field_name::Union{$field_type, Nothing}))
                    end
                end
            end
        end
    end

    quote
        mutable struct $(esc(name))
            $(fields...)
            $(esc(name))() = new($(repeat([nothing], length(fields))...))
            $(esc(name))(params::Dict) = begin
                obj = new($(repeat([nothing], length(fields))...))
                obj.id = get(params, "id", get(params, :id, nothing))
                for f in $schema_fields
                    val = get(params, string(f), get(params, f, nothing))
                    setproperty!(obj, f, val)
                end
                obj
            end
        end

        ($(esc(:ResourceModule))).table_name(::Type{$(esc(name))}) = $table
        ($(esc(:ResourceModule))).schema(::Type{$(esc(name))}) = $schema_fields
    end
end

end # module ResourceModule
