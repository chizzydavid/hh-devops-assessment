# Stage 1: Install production dependencies
FROM node:22-alpine AS dependencies

WORKDIR /app

# Copy dependency manifests first for better layer caching
COPY package.json package-lock.json ./

# Install production dependencies only
RUN npm ci --omit=dev && npm cache clean --force



# Stage 2: Production runtime
FROM node:22-alpine AS production

WORKDIR /app

# Copy dependencies and source code
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node .env ./
COPY --chown=node:node app/ ./app/

# Run the application as a non-root user
USER node

# Expose port 8001
EXPOSE 8001

CMD ["node", "app/index.js"]
