from flask import Flask, jsonify
import logging

app = Flask(__name__)
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

@app.route("/")
def hello():
    return jsonify(message="Hello World")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8082)
