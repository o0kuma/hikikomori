# Flutter Web → nginx. Build from repository root:
#   docker build -f mobile/Dockerfile --build-arg CORE_API_BASE=https://msn.iykyka.com .
ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:3.32.7
FROM ${FLUTTER_IMAGE} AS build

WORKDIR /app
ARG CORE_API_BASE=https://msn.iykyka.com

COPY mobile/pubspec.yaml mobile/pubspec.lock ./
RUN flutter pub get

COPY mobile/ .
RUN flutter build web --release \
      --dart-define=CORE_API_BASE=${CORE_API_BASE}

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deploy/nginx-web.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
