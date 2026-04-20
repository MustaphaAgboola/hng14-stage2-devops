# Stage 1: install production dependencies
FROM node:20-slim AS builder
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev

# Stage 2: lean production image
FROM node:20-slim
WORKDIR /app

# Create non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy only production node_modules from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy application source
COPY app.js package.json ./
COPY views/ ./views/

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1)).on('error', () => process.exit(1))"

CMD ["node", "app.js"]
