const db = require("../models/db");

const setupDatabase = async () => {
  const schema = [
    `DROP TABLE IF EXISTS order_items;`,
    `DROP TABLE IF EXISTS orders;`,
    `DROP TABLE IF EXISTS products;`,
    `DROP TABLE IF EXISTS customers;`,
    `CREATE TABLE customers (
        customer_id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        country VARCHAR(50)
      );`,
    `CREATE TABLE products (
        product_id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        category VARCHAR(50),
        price DECIMAL(10,2)
      );`,
    `CREATE TABLE orders (
        order_id INT PRIMARY KEY AUTO_INCREMENT,
        customer_id INT,
        order_date DATE,
        status VARCHAR(20),
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
      );`,
    `CREATE TABLE order_items (
        order_item_id INT PRIMARY KEY AUTO_INCREMENT,
        order_id INT,
        product_id INT,
        quantity INT,
        unit_price DECIMAL(10,2),
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
        FOREIGN KEY (product_id) REFERENCES products(product_id)
      );`,
    `INSERT INTO customers (name, email, country) VALUES
        ('Alice Smith', 'alice@example.com', 'USA'),
        ('Bob Jones', 'bob@example.com', 'Canada'),
        ('Charlie Zhang', 'charlie@example.com', 'UK');`,
    `INSERT INTO products (name, category, price) VALUES
        ('Laptop', 'Electronics', 1200.00),
        ('Smartphone', 'Electronics', 800.00),
        ('Desk Chair', 'Furniture', 150.00),
        ('Coffee Maker', 'Appliances', 85.50);`,
    `INSERT INTO orders (customer_id, order_date, status) VALUES
        (1, '2023-11-15', 'Shipped'),
        (2, '2023-11-20', 'Pending'),
        (1, '2023-12-01', 'Delivered'),
        (3, '2023-12-03', 'Cancelled');`,
    `INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
        (1, 1, 1, 1200.00),
        (1, 4, 2, 85.50),
        (2, 2, 1, 800.00),
        (3, 3, 2, 150.00),
        (4, 1, 1, 1200.00);`,
  ];

  try {
    console.log("Setting up the database...");
    for (const query of schema) {
      await db.query(query);
    }
    console.log("Database setup completed successfully!");
  } catch (error) {
    console.error("Error setting up the database:", error);
  } finally {
    db.end(); // Close the database connection
  }
};

setupDatabase();
