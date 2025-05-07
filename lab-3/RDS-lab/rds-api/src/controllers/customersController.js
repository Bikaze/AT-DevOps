const db = require("../models/db");

class CustomersController {
  async getAllCustomers(req, res) {
    try {
      const [customers] = await db.query("SELECT * FROM customers");
      res.status(200).json(customers);
    } catch (error) {
      res.status(500).json({ message: "Error retrieving customers", error });
    }
  }

  async getCustomerById(req, res) {
    const { id } = req.params;
    try {
      const [customer] = await db.query(
        "SELECT * FROM customers WHERE customer_id = ?",
        [id]
      );
      if (customer.length > 0) {
        res.status(200).json(customer[0]);
      } else {
        res.status(404).json({ message: "Customer not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error retrieving customer", error });
    }
  }

  async createCustomer(req, res) {
    const { name, email, country } = req.body;
    try {
      const [result] = await db.query(
        "INSERT INTO customers (name, email, country) VALUES (?, ?, ?)",
        [name, email, country]
      );
      res
        .status(201)
        .json({ customer_id: result.insertId, name, email, country });
    } catch (error) {
      res.status(500).json({ message: "Error creating customer", error });
    }
  }

  async updateCustomer(req, res) {
    const { id } = req.params;
    const { name, email, country } = req.body;
    try {
      const [result] = await db.query(
        "UPDATE customers SET name = ?, email = ?, country = ? WHERE customer_id = ?",
        [name, email, country, id]
      );
      if (result.affectedRows > 0) {
        res.status(200).json({ message: "Customer updated successfully" });
      } else {
        res.status(404).json({ message: "Customer not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error updating customer", error });
    }
  }

  async deleteCustomer(req, res) {
    const { id } = req.params;
    try {
      const [result] = await db.query(
        "DELETE FROM customers WHERE customer_id = ?",
        [id]
      );
      if (result.affectedRows > 0) {
        res.status(204).send();
      } else {
        res.status(404).json({ message: "Customer not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error deleting customer", error });
    }
  }
}

module.exports = CustomersController;
