FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="mi-app-web"
LABEL org.opencontainers.image.description="Aplicación web estática desplegada con Jenkins y Docker"
LABEL org.opencontainers.image.source="https://github.com/TU_USUARIO/TU_REPOSITORIO"

RUN rm -rf /usr/share/nginx/html/*

COPY app/index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://localhost/ || exit 1
