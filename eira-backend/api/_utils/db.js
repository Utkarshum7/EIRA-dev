// api/_utils/db.js
const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL ||
  `postgresql://${process.env.DB_USER}:${process.env.DB_PASS}@${process.env.DB_HOST || '127.0.0.1'}:${process.env.DB_PORT || 5432}/${process.env.DB_NAME || 'postgres'}`;

// If the DB host is localhost/127.0.0.1 (Cloud SQL Proxy), do NOT use SSL.
// For non-local hosts (direct DB connection), enable SSL but don't reject unauthorized (optional).
let sslOption = false;
try {
  const parsed = new URL(connectionString);
  const host = parsed.hostname || '';
  if (host === '127.0.0.1' || host === 'localhost') {
    sslOption = false;
  } else {
    sslOption = { rejectUnauthorized: false };
  }
} catch (err) {
  // If parse fails, default to no ssl to avoid blocking proxy case
  sslOption = false;
}

const pool = new Pool({
  connectionString,
  ssl: sslOption,
});

module.exports = pool;
