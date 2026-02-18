use axum::{
    routing::get,
    Json, Router,
};
use serde_json::{Value, json};
use std::net::SocketAddr;

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(handler));

    let addr = SocketAddr::from(([0, 0, 0, 0], 8091));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn handler() -> Json<Value> {
    Json(json!({ "message": "Hello World" }))
}
