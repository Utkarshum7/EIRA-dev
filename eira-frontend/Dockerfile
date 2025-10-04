# Build stage: Flutter web build
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
ARG BACKEND_URL
ENV BACKEND_URL=
RUN flutter build web --release --dart-define=BACKEND_URL=

# Serve stage: NGINX
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
# Optional: healthcheck
HEALTHCHECK CMD wget --spider -q http://localhost/ || exit 1
