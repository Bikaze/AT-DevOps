const db = require("../models/db");

class OrdersController {
  async getAllOrders(req, res) {
    try {
      const [orders] = await db.query("SELECT * FROM orders");
      res.status(200).json(orders);
    } catch (error) {
      res.status(500).json({ message: "Error retrieving orders", error });
    }
  }

  async getOrderById(req, res) {
    const { id } = req.params;
    try {
      const [order] = await db.query(
        "SELECT * FROM orders WHERE order_id = ?",
        [id]
      );
      if (order.length > 0) {
        res.status(200).json(order[0]);
      } else {
        res.status(404).json({ message: "Order not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error retrieving order", error });
    }
  }

  async createOrder(req, res) {
    const { customer_id, order_date, status } = req.body;
    try {
      const [result] = await db.query(
        "INSERT INTO orders (customer_id, order_date, status) VALUES (?, ?, ?)",
        [customer_id, order_date, status]
      );
      res
        .status(201)
        .json({ order_id: result.insertId, customer_id, order_date, status });
    } catch (error) {
      res.status(500).json({ message: "Error creating order", error });
    }
  }

  async updateOrder(req, res) {
    const { id } = req.params;
    const { customer_id, order_date, status } = req.body;
    try {
      const [result] = await db.query(
        "UPDATE orders SET customer_id = ?, order_date = ?, status = ? WHERE order_id = ?",
        [customer_id, order_date, status, id]
      );
      if (result.affectedRows > 0) {
        res.status(200).json({ message: "Order updated successfully" });
      } else {
        res.status(404).json({ message: "Order not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error updating order", error });
    }
  }

  async deleteOrder(req, res) {
    const { id } = req.params;
    try {
      const [result] = await db.query("DELETE FROM orders WHERE order_id = ?", [
        id,
      ]);
      if (result.affectedRows > 0) {
        res.status(204).send();
      } else {
        res.status(404).json({ message: "Order not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error deleting order", error });
    }
  }
}

module.exports = OrdersController;
