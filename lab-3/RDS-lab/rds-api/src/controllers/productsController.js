const db = require("../models/db");

class ProductsController {
  async getAllProducts(req, res) {
    try {
      const [products] = await db.query("SELECT * FROM products");
      res.status(200).json(products);
    } catch (error) {
      res.status(500).json({ message: "Error retrieving products", error });
    }
  }

  async getProductById(req, res) {
    const { id } = req.params;
    try {
      const [product] = await db.query(
        "SELECT * FROM products WHERE product_id = ?",
        [id]
      );
      if (product.length > 0) {
        res.status(200).json(product[0]);
      } else {
        res.status(404).json({ message: "Product not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error retrieving product", error });
    }
  }

  async createProduct(req, res) {
    const { name, category, price } = req.body;
    try {
      const [result] = await db.query(
        "INSERT INTO products (name, category, price) VALUES (?, ?, ?)",
        [name, category, price]
      );
      res
        .status(201)
        .json({ product_id: result.insertId, name, category, price });
    } catch (error) {
      res.status(500).json({ message: "Error creating product", error });
    }
  }

  async updateProduct(req, res) {
    const { id } = req.params;
    const { name, category, price } = req.body;
    try {
      const [result] = await db.query(
        "UPDATE products SET name = ?, category = ?, price = ? WHERE product_id = ?",
        [name, category, price, id]
      );
      if (result.affectedRows > 0) {
        res.status(200).json({ message: "Product updated successfully" });
      } else {
        res.status(404).json({ message: "Product not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error updating product", error });
    }
  }

  async deleteProduct(req, res) {
    const { id } = req.params;
    try {
      const [result] = await db.query(
        "DELETE FROM products WHERE product_id = ?",
        [id]
      );
      if (result.affectedRows > 0) {
        res.status(204).send();
      } else {
        res.status(404).json({ message: "Product not found" });
      }
    } catch (error) {
      res.status(500).json({ message: "Error deleting product", error });
    }
  }
}

module.exports = ProductsController;
