const mysql = require("mysql2");
const dotenv = require("dotenv");

dotenv.config();

// Create a connection pool with promise support
const pool = mysql
  .createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  })
  .promise(); // Use the promise wrapper here

module.exports = pool;
