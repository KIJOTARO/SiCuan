# ===== BUILD STAGE =====
FROM oven/bun:1 AS builder
WORKDIR /app

# Set NODE_ENV di build stage
ENV NODE_ENV=production

# Copy package files
COPY package.json bun.lock ./
RUN bun install

# Copy source code
COPY src ./src
COPY prisma ./prisma
COPY tsconfig.json ./

# Generate Prisma dengan NODE_ENV yang benar
RUN bunx prisma generate

# Build project
RUN bun run build

# ===== PRODUCTION STAGE =====
FROM oven/bun:1-slim AS runner
WORKDIR /app

# Set environment variables di awal
ENV NODE_ENV=production
ENV PORT=8080

# Install dependencies
RUN apt-get update && apt-get install -y openssl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 999 --ingroup nodejs sicuan

# Copy package files dan install production dependencies
COPY package.json bun.lock ./
RUN bun install --production

# Copy yang dibutuhkan untuk production
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

# Copy .env.production jika ada
#COPY .env.production* ./

# Change ownership dan permissions
RUN chown -R sicuan:nodejs /app && chmod -R 755 /app

# Switch to non-root user
USER sicuan

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD bun --eval "fetch('http://localhost:8080/health').then(r => process.exit(r.ok ? 0 : 1))" || exit 1

# Jalankan aplikasi

CMD ["bun", "run", "dist/server.js"]
