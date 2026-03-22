# --- STAGE 1: Build (The "Heavy Lifting") ---
FROM node:18-bookworm-slim AS build
WORKDIR /app

# FIX: Install compilers in Stage 1 so native modules (sqlite3, etc.) can build
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy the entire project from your local directory
COPY . .

# Run the build process
RUN yarn install --immutable && yarn build:all

# --- STAGE 2: Runtime (The "Slim Image" for the Pi) ---
FROM node:18-bookworm-slim
WORKDIR /app

# Install only the runtime library for Postgres (smaller footprint)
RUN apt-get update && apt-get install -y libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy the compiled bundle from Stage 1
COPY --from=build /app/packages/backend/dist/bundle.tar.gz .
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Install only production-ready modules
RUN yarn install --production --network-timeout 600000

# Optimization for Raspberry Pi 4GB/8GB RAM
ENV NODE_OPTIONS="--max-old-space-size=2048"

# Start the app using both config files
CMD ["node", "packages/backend/dist/index.js", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
