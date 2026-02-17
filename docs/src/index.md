# Suindara.jl

Phoenix-inspired web framework for Julia.

## Quick Start

```julia
using Suindara

# Define a router
@router MyRouter begin
    get("/", conn -> resp(conn, 200, "Hello!"))
end

# Start server (via HTTP.jl)
# Suindara.start(MyRouter, port=8080)
```

## Modules

```@docs
Conn
assign
halt!
resp
run_pipeline
plug_cors
plug_request_id
plug_form_parser
make_static_plug
make_bearer_plug
cast
validate_required
validate_format
validate_length
validate_inclusion
```
