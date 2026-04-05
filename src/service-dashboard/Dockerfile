# Stage 1: Build React frontend
FROM node:18-alpine AS builder
WORKDIR /app/client

COPY client/package*.json ./
RUN npm ci

COPY client/ ./
RUN npm run build

# Stage 2: Build final image with Node.js backend
FROM node:18-alpine
WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy backend files
COPY package*.json ./
RUN npm ci --omit=dev

# Copy built React frontend from builder stage
COPY --from=builder /app/client/dist ./client/dist

# Copy other necessary files
COPY server.js .
COPY .env.example .

# Expose port
EXPOSE 3000

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the server
CMD ["node", "server.js"]
