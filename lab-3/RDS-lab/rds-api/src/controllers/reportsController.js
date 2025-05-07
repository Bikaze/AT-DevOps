const db = require("../models/db");
const queries = require("../models/queries");

class ReportsController {
  async getTopCustomers(req, res) {
    try {
      const [results] = await db.query(queries.topCustomersBySpending);
      res.status(200).json(results);
    } catch (error) {
      res.status(500).json({ message: "Error fetching top customers", error });
    }
  }

  async getMonthlySalesReport(req, res) {
    try {
      const [results] = await db.query(queries.monthlySalesReport);
      res.status(200).json(results);
    } catch (error) {
      res
        .status(500)
        .json({ message: "Error fetching monthly sales report", error });
    }
  }

  async getProductsNeverOrdered(req, res) {
    try {
      const [results] = await db.query(queries.productsNeverOrdered);
      res.status(200).json(results);
    } catch (error) {
      res
        .status(500)
        .json({ message: "Error fetching products never ordered", error });
    }
  }

  async getAverageOrderValueByCountry(req, res) {
    try {
      const [results] = await db.query(queries.averageOrderValueByCountry);
      res.status(200).json(results);
    } catch (error) {
      res
        .status(500)
        .json({
          message: "Error fetching average order value by country",
          error,
        });
    }
  }

  async getFrequentBuyers(req, res) {
    try {
      const [results] = await db.query(queries.frequentBuyers);
      res.status(200).json(results);
    } catch (error) {
      res
        .status(500)
        .json({ message: "Error fetching frequent buyers", error });
    }
  }
}

module.exports = ReportsController;
