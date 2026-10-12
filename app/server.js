const http = require("http");
const { Pool } = require("pg");
const pool = new Pool({
  host: process.env.DB_HOST, port: 5432,
  user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME,
});
http.createServer(async (req, res) => {
  res.setHeader("Content-Type", "application/json");
  try {
    if (req.url === "/health") {
      const r = await pool.query("SELECT now() AS db_time");
      return res.end(JSON.stringify({ status: "UP", db_host: process.env.DB_HOST, db_time: r.rows[0].db_time }));
    }
    if (req.url === "/students") {
      const r = await pool.query("SELECT * FROM students ORDER BY id");
      return res.end(JSON.stringify(r.rows));
    }
    res.statusCode = 404; res.end(JSON.stringify({ error: "Not found" }));
  } catch (e) { res.statusCode = 500; res.end(JSON.stringify({ error: e.message })); }
}).listen(3000, () => console.log("Backend :3000, DB_HOST=" + process.env. DB_HOST));
