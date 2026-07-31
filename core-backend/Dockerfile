# core-backend — Go (Gin). Production DB via DATABASE_URL (Postgres).
# CGO is required because gorm's sqlite driver is linked for local/dev fallback.
FROM golang:1.24-bookworm AS build
WORKDIR /src

# go.mod may request a newer toolchain than the image — let Go fetch it.
ENV GOTOOLCHAIN=auto
ENV CGO_ENABLED=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends gcc libc6-dev \
  && rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o /out/core-backend .

FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --system --uid 10001 --create-home app

COPY --from=build /out/core-backend /usr/local/bin/core-backend
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD curl -fsS http://127.0.0.1:8080/health || exit 1
CMD ["core-backend"]
