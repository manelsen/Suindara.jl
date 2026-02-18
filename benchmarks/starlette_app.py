from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
import uvicorn

async def homepage(request):
    return JSONResponse({'message': 'Hello World'})

routes = [
    Route('/', homepage),
]

app = Starlette(debug=False, routes=routes)

if __name__ == "__main__":
    uvicorn.run(app, host='0.0.0.0', port=8089, log_level='critical')
