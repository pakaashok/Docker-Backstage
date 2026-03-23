# --- STAGE 1: Build ---
FROM node:20 AS build
WORKDIR /app

# Install only the necessary build-essential tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    build-essential \
    pkg-config \
    libv8-dev \
    libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Enable Corepack for Yarn 4
RUN corepack enable

# Copy only dependency files
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
COPY packages/backend/package.json packages/backend/package.json
COPY packages/app/package.json packages/app/package.json

# ✅ FIX: Tell Yarn to ignore the broken patches and just install the code
ENV YARN_ENABLE_IMMUTABLE_INSTALLS=false
ENV IVM_FLAGS="--build-from-source"

# Run install
RUN yarn install --network-timeout 600000

# Copy the rest of the project and build
COPY . .
RUN yarn build:all

# --- STAGE 2: Runtime ---
FROM node:20-slim
WORKDIR /app

# Install runtime library for Postgres
RUN apt-get update && apt-get install -y libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy the compiled bundle
COPY --from=build /app/packages/backend/dist/bundle.tar.gz .
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Install production deps
RUN corepack enable && yarn install --production --network-timeout 600000

COPY app-config.yaml app-config.production.yaml ./

ENV NODE_OPTIONS="--max-old-space-size=3072"
ENV NODE_ENV=production

# Start the app
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
