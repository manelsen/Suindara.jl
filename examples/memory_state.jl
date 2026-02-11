module RecommenderApp
    using Suindara
    using LinearAlgebra # Julia é feita para isso
    using Random

    # ESTADO GLOBAL PERSISTENTE
    # Em PHP, isso morreria ao fim do request.
    # Em Julia, isso fica na RAM. 
    # Imagine uma matriz de 10.000 produtos x 500 features.
    const PRODUCT_MATRIX = rand(Float32, 500, 10000) 
    
    module RecController
        using Suindara
        using LinearAlgebra
        using ..RecommenderApp: PRODUCT_MATRIX # Acesso direto à memória RAM
        
        function recommend(conn::Conn)
            # Perfil do usuário (Vetor de 500 features) vindo do JSON
            # Ex: [0.1, 0.5, ... 0.9]
            user_vector = convert(Vector{Float32}, conn.params["features"])
            
            # CÁLCULO PESADO EM TEMPO REAL
            # Multiplicação de Matriz (User Vector * Todos os Produtos)
            # Calcula o "score" de compatibilidade para 10.000 produtos instantaneamente.
            scores = user_vector' * PRODUCT_MATRIX
            
            # Pega o índice do produto com maior score
            top_product_idx = argmax(scores)
            best_score = scores[top_product_idx]
            
            return render_json(conn, Dict(
                "recommended_product_id" => top_product_idx[2], # argmax returns CartesianIndex
                "match_score" => best_score,
                "message" => "Calculado sobre 10.000 produtos em memória RAM"
            ))
        end
    end

    @router RecRouter begin
        post("/recommend", RecController.recommend)
    end

    function start(port=8082)
        println("Recommender AI Server carregado.")
        println("Matriz de Produtos (500x10000) mantida na RAM.")
        
        HTTP.serve(port) do req
            conn = Conn(req)
            conn = plug_json_parser(conn) # Parse JSON body
            match_and_dispatch(RecRouter, req)
        end
    end
end
