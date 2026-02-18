using Oxygen
using HTTP
using JSON3

@get "/" function(req::HTTP.Request)
    return Dict("message" => "Hello World")
end

serve(port=8086)
