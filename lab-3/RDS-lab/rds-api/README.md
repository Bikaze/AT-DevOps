# Node API Project

## Overview
This project is a Node.js application that interacts with a MySQL database hosted on AWS RDS. It provides a RESTful API for managing customers, products, and orders, as well as generating reports based on complex queries.

## Project Structure
```
node-api-project
├── src
│   ├── app.js
│   ├── routes
│   │   ├── customers.js
│   │   ├── orders.js
│   │   ├── products.js
│   │   └── reports.js
│   ├── controllers
│   │   ├── customersController.js
│   │   ├── ordersController.js
│   │   ├── productsController.js
│   │   └── reportsController.js
│   ├── models
│   │   ├── db.js
│   │   └── queries.js
│   └── utils
│       └── dbConfig.js
├── docker-compose.yml
├── Dockerfile
├── package.json
├── package-lock.json
├── README.md
└── sql
    ├── create_tables.sql
    ├── insert_data.sql
    └── queries.sql
```

## Setup Instructions

1. **Clone the Repository**
   ```
   git clone <repository-url>
   cd node-api-project
   ```

2. **Install Dependencies**
   ```
   npm install
   ```

3. **Configure Database**
   Update the `src/utils/dbConfig.js` file with your MySQL database credentials.

4. **Run Database Setup**
   Execute the SQL scripts located in the `sql` directory to create tables and insert initial data into your MySQL database.

5. **Run the Application**
   ```
   npm start
   ```

6. **Access the API**
   The API will be available at `http://localhost:3000`. You can use tools like Postman or curl to interact with the endpoints.

## API Documentation
- **Customers**
  - `GET /customers`: Retrieve all customers
  - `GET /customers/:id`: Retrieve a customer by ID
  - `POST /customers`: Create a new customer
  - `PUT /customers/:id`: Update a customer by ID
  - `DELETE /customers/:id`: Delete a customer by ID

- **Products**
  - `GET /products`: Retrieve all products
  - `GET /products/:id`: Retrieve a product by ID
  - `POST /products`: Create a new product
  - `PUT /products/:id`: Update a product by ID
  - `DELETE /products/:id`: Delete a product by ID

- **Orders**
  - `GET /orders`: Retrieve all orders
  - `GET /orders/:id`: Retrieve an order by ID
  - `POST /orders`: Create a new order
  - `PUT /orders/:id`: Update an order by ID
  - `DELETE /orders/:id`: Delete an order by ID

- **Reports**
  - `GET /reports/top-customers`: Get top customers by spending
  - `GET /reports/monthly-sales`: Get monthly sales report (Only Shipped/Delivered)
  - `GET /reports/products-never-ordered`: Get products never ordered
  - `GET /reports/average-order-value`: Get average order value by country
  - `GET /reports/frequent-buyers`: Get frequent buyers (More Than One Order)

## Docker Setup
To run the application using Docker, use the following command:
```
docker-compose up
```

This will build the Docker image and start the application along with the MySQL database.

## License
This project is licensed under the MIT License.