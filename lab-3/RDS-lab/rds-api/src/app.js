const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors"); // Import cors
const customersRoutes = require("./routes/customers");
const ordersRoutes = require("./routes/orders");
const productsRoutes = require("./routes/products");
const reportsRoutes = require("./routes/reports");

const app = express();

// Middleware
app.use(bodyParser.json());
app.use(cors()); // Enable CORS

// Routes
app.use("/api/customers", customersRoutes);
app.use("/api/orders", ordersRoutes);
app.use("/api/products", productsRoutes);
app.use("/api/reports", reportsRoutes);

// Default route
app.get("/", (req, res) => {
  res.send("Welcome to the RDS API!");
});

module.exports = app;
