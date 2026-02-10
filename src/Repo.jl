module RepoModule

using ..ChangesetModule

export Repo

module Repo
    using SQLite
    using DBInterface
    using ...ChangesetModule # Need three dots to go back up to Suindara then down to ChangesetModule? 
                             # Actually ChangesetModule is a sibling of RepoModule inside Suindara.
                             # If Repo is nested in RepoModule, it gets complicated.

    # Simpler approach: Define functions on the type itself or just use the module name.
    # Let's go with the module name approach, but simplify the nesting.
    
    const _DB = Ref{Union{SQLite.DB, Nothing}}(nothing)

    function connect(path::String)
        _DB[] = SQLite.DB(path)
    end

    function get_db()
        if _DB[] === nothing
            error("Database not connected. Call Repo.connect(path) first.")
        end
        return _DB[]
    end

    function execute(sql::String, params=())
        DBInterface.execute(get_db(), sql, params)
    end

    function query(sql::String, params=())
        return DBInterface.execute(get_db(), sql, params)
    end
    
    function insert(ch::ChangesetModule.Changeset, table::String)
        if !ch.valid
            error("Cannot insert invalid changeset")
        end
        
        fields = keys(ch.changes) |> collect
        values_list = values(ch.changes) |> collect
        
        field_names = join(fields, ", ")
        placeholders = join(["?" for _ in fields], ", ")
        
        sql = "INSERT INTO $table ($field_names) VALUES ($placeholders)"
        
        execute(sql, values_list)
        return ch
    end
end

end # module