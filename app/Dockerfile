# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/app .

# Run stage
FROM alpine:3.19
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /out/app /app
USER appuser
EXPOSE 8080
CMD ["/app"]
