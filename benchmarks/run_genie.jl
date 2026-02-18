using Genie, Genie.Router, Genie.Renderer.Json

route("/") do
  json(Dict("message" => "Hello World"))
end

up(8085, async=false)
