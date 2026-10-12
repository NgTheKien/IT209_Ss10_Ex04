#!/usr/bin/env bash
# Session 10 - Ex4: Custom Bridge Network + Named Volume bang Docker CLI
set -euo pipefail

NETWORK=app-net
VOLUME=db-data
DB_CONTAINER=db-server
APP_CONTAINER=app-container
DB_USER=app_user
DB_PASSWORD=App@123
DB_NAME=app_db

wait_for_db() {
  echo ">> Doi PostgreSQL san sang..."
  until docker exec "$DB_CONTAINER" pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
    sleep 1
  done
  echo ">> PostgreSQL READY"
}

run_db() {
  docker run -d \
    --name "$DB_CONTAINER" \
    --network "$NETWORK" \
    -v "$VOLUME":/var/lib/postgresql/data \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    postgres:15-alpine
}

psql_exec() {
  docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "$1"
}

echo "===== 0. Tao code Backend (Node.js + pg) ====="
mkdir -p app
cat > app/package.json <<'JSON'
{ "name": "backend", "version": "1.0.0", "dependencies": { "pg": "^8.13.0" } }
JSON
cat > app/server.js <<'JS'
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
JS

echo "===== Don dep lan chay truoc ====="
docker rm -f "$APP_CONTAINER" "$DB_CONTAINER" >/dev/null 2>&1 || true
docker volume rm "$VOLUME" >/dev/null 2>&1 || true
docker network rm "$NETWORK" >/dev/null 2>&1 || true

echo "===== 1. Tao Custom Bridge Network: $NETWORK ====="
docker network create --driver bridge "$NETWORK"

echo "===== 2. Tao Named Volume: $VOLUME ====="
docker volume create "$VOLUME"

echo "===== 3. Chay Database container: $DB_CONTAINER ====="
run_db
wait_for_db

echo "===== 4. Chay Backend container: $APP_CONTAINER ====="
docker run -d \
  --name "$APP_CONTAINER" \
  --network "$NETWORK" \
  -p 3005:3000 \
  -v "$(pwd)/app":/app -w /app \
  -e DB_HOST="$DB_CONTAINER" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_NAME="$DB_NAME" \
  node:20-alpine \
  sh -c "npm install --omit=dev --no-audit --no-fund && node server.js"

echo "===== 5. Ping db-server tu Backend (DNS noi bo) ====="
docker exec "$APP_CONTAINER" ping -c 2 "$DB_CONTAINER"

echo "===== 6. Test Data Persistence ====="
echo ">> 6.1 Them du lieu"
psql_exec "CREATE TABLE IF NOT EXISTS students (id SERIAL PRIMARY KEY, code VARCHAR(20) UNIQUE, name VARCHAR(100));"
psql_exec "INSERT INTO students (code, name) VALUES ('B24DCCN001','Nguyen Van An'), ('B24DCCN002','Tran Thi Binh');"
psql_exec "SELECT * FROM students;"

echo ">> 6.2 Xoa cung container DB"
docker rm -f "$DB_CONTAINER"

echo ">> 6.3 Tao lai container DB moi, gan cung volume $VOLUME"
run_db
wait_for_db

echo ">> 6.4 Xac minh du lieu khong bi mat"
psql_exec "SELECT * FROM students;"

echo ">> 6.5 Backend doc du lieu qua hostname db-server"
sleep 5
curl -s http://localhost:3005/health; echo
curl -s http://localhost:3005/students; echo

echo "===== HOAN THANH ====="
