# Stage 1: Build
FROM node:16-alpine AS builder

# Set working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the application code
COPY . .

# Stage 2: Production
FROM node:16-alpine

# Set working directory
WORKDIR /usr/src/app

# Copy only the production dependencies and application code
COPY --from=builder /usr/src/app .

# Expose the application port
EXPOSE 3000

# Command to run the application
CMD ["node", "index.js"]