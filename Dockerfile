# ─────────────────────────────────────────────────────────────
# Stage 1 — Build do cliente React (Vite + Tailwind)
# ─────────────────────────────────────────────────────────────
FROM node:22-alpine AS client-build

WORKDIR /app/client

# Cache de dependências npm antes de copiar o resto
COPY client/package.json client/package-lock.json ./
RUN npm ci --prefer-offline

# Copia o restante do fonte e builda
COPY client/ ./
RUN npm run build

# ─────────────────────────────────────────────────────────────
# Stage 2 — Build do servidor Go
# ─────────────────────────────────────────────────────────────
FROM golang:1.26-alpine AS go-build

# Instala utilitários mínimos (sem CGO — Go puro)
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Cache de módulos antes de copiar o código
COPY go.mod go.sum ./
RUN go mod download

# Copia tudo e compila
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" \
    -o /wacalls ./cmd/server

# ─────────────────────────────────────────────────────────────
# Stage 3 — Imagem de runtime mínima
# ─────────────────────────────────────────────────────────────
FROM alpine:3.20

# Certificados para HTTPS + timezone
RUN apk add --no-cache ca-certificates tzdata

# Usuário não-root (segurança)
RUN adduser -D -u 1001 -g "wacalls" node

WORKDIR /app

# Copia binário compilado e assets do cliente
COPY --from=go-build   --chown=node:node /wacalls          ./wacalls
COPY --from=client-build --chown=node:node /app/client/dist  ./client/dist

# Diretório de dados persistentes (volume)
RUN mkdir -p /app/data && chown node:node /app/data

USER node

EXPOSE 8080

# WACALLS_TOKEN — deixar vazio desativa autenticação
ENV WACALLS_TOKEN=""

CMD ["./wacalls", \
     "-addr",   ":8080", \
     "-static", "client/dist", \
     "-db",     "/app/data/wacalls.db"]
