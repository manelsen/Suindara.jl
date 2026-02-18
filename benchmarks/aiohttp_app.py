from aiohttp import web

async def handle(request):
    return web.json_response({'message': 'Hello World'})

app = web.Application()
app.add_routes([web.get('/', handle)])

if __name__ == '__main__':
    web.run_app(app, port=8088, access_log=None)
