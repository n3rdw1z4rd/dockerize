// Reports what reached the container, for tests/docker.sh.
const fs = require('fs');
const http = require('http');

http
  .createServer((_req, res) => {
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify({
      secret: process.env.DEMO_SECRET ?? null,
      extra: process.env.DEMO_EXTRA ?? null,
      envInImage: fs.existsSync('.env'),
      envLocalInImage: fs.existsSync('.env.local'),
      exampleInImage: fs.existsSync('.env.example'),
    }));
  })
  .listen(process.env.PORT || 3000);
