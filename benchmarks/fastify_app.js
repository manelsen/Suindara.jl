const fastify = require('fastify')({ logger: false });
const port = 8084;

fastify.get('/', async (request, reply) => {
  return { message: 'Hello World' }
})

const start = async () => {
  try {
    await fastify.listen({ port: port, host: '0.0.0.0' })
    console.log(`Fastify listening at http://localhost:${port}`)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}
start()
