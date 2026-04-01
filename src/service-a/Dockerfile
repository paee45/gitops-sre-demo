# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /build

# Download dependencies first (layer cache)
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o app .

# ---- runtime ----------------------------------------------------------------
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /build/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
