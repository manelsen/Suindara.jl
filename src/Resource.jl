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

export ResourceController, schema, table_name, primary_key

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
        id = conn.params[:id]
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
        id = conn.params[:id]
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
        id = conn.params[:id]
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

end # module ResourceModule
