module AsyncApp
    using Suindara
    using Base.Threads
    
    # Simulação de um Controller
    module ReportController
        using Suindara
        using Base.Threads
        
        function create(conn::Conn)
            # Simula recebimento de dados
            user_id = get(conn.params, "user_id", "anon")
            
            println("[REQ] Recebido pedido de relatório para: $user_id")
            
            # MAGIA: Fire-and-forget nativo
            # Não precisa de Redis, não precisa de Worker separado.
            Threads.@spawn begin
                sleep(2) # Simula 2 segundos de processamento pesado
                println("[WORKER] Relatório de $user_id processado na Thread $(Threads.threadid())")
                # Aqui poderiamos salvar no banco ou mandar email
            end
            
            return resp(conn, 202, "{"status": "processing"}", content_type="application/json")
        end
    end

    # Router Definition
    @router JobRouter begin
        post("/reports", ReportController.create)
    end

    function start(port=8081)
        println("Server rodando na porta $port com $(Threads.nthreads()) threads.")
        println("Tente: curl -X POST http://localhost:$port/reports -d '{"user_id": "dev_php"}' -H 'Content-Type: application/json'")
        
        # Suindara server loop (simplificado para exemplo)
        HTTP.serve(port) do req
            conn = plug_json_parser(Conn(req)) # Usando nosso plug de JSON
            match_and_dispatch(JobRouter, req)
        end
    end
end
