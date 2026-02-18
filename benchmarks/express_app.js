const express = require('express');
const app = express();
const port = 8083;

app.get('/', (req, res) => {
  res.json({ message: 'Hello World' });
});

app.listen(port, () => {
  console.log(`Express listening at http://localhost:${port}`);
});
