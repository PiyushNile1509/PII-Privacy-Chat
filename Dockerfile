FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app
COPY presdio_pii/ ./
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpine
COPY --from=0 /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]