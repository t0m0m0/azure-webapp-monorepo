# Build note: this Dockerfile is meant to be invoked with the REPO ROOT as
# build context (so /docs is reachable for gen-questions). The Makefile does
# `docker build -f app/Dockerfile .` accordingly.

# 1. Web build
FROM node:20-alpine AS web-build
WORKDIR /web
COPY app/web/package.json app/web/package-lock.json* ./
RUN npm ci
COPY app/web ./
RUN npm run build

# 2. Go build (generates questions.json from /docs, then builds server)
FROM golang:1.22-alpine AS go-build
WORKDIR /src
COPY app/go.mod ./
COPY app/main.go ./
COPY app/internal ./internal
COPY app/cmd ./cmd
COPY docs /docs
COPY --from=web-build /web/dist ./web/dist
RUN mkdir -p data && go run ./cmd/gen-questions -in /docs/AZ-104_STUDY_GUIDE.md -out data/questions.json
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/app .

# 3. Run
FROM alpine:3.19
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=go-build /out/app /app
USER appuser
EXPOSE 8080
CMD ["/app"]
