# Small image: Alpine base, no npm install step (the app has no dependencies), runs as a non-root user.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json server.js ./

USER node
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["node", "server.js"]
