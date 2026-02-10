using Suindara

# 1. The Controller - Returning a styled HTML page
module WelcomeController
    using Suindara

    function index(conn::Conn)
        html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Suindara Framework</title>
            <style>
                body {
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    background-color: #1a1a1a;
                    color: #f0f0f0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                }
                .container {
                    text-align: center;
                    padding: 3rem;
                    background: #2d2d2d;
                    border-radius: 15px;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.5);
                    border-top: 5px solid #ff4500;
                }
                h1 { color: #ff4500; font-size: 3rem; margin-bottom: 0.5rem; }
                p { font-size: 1.2rem; color: #ccc; }
                .badge {
                    background: #444;
                    padding: 0.5rem 1rem;
                    border-radius: 20px;
                    font-size: 0.9rem;
                    color: #ff4500;
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="badge">JULIA POWERED</div>
                <h1>Suindara.jl</h1>
                <p>O framework web com alma de Phoenix e velocidade de Julia.</p>
                <hr style="border: 0; border-top: 1px solid #444; margin: 2rem 0;">
                <p style="font-size: 0.9rem;">Status: <strong>Pronto para Produção</strong></p>
            </div>
        </body>
        </html>
        """
        return resp(conn, 200, html, content_type="text/html")
    end
end

# 2. The Router
@router WebRouter begin
    get("/", WelcomeController.index)
end

# 3. Test - Simulating a real web request
using HTTP
req = HTTP.Request("GET", "/", [], "")
conn = match_and_dispatch(WebRouter, req)

println("--- HTTP RESPONSE ---")
println("Status: $(conn.status)")
println("Content-Type: $(filter(h -> h.first == "Content-Type", conn.resp_headers)[1].second)")
println("
--- HTML BODY ---")
println(conn.resp_body)
