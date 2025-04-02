# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. Instalación de dependencias corregida
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      libpq5 \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development test" \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true

# 2. Etapa de construcción
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      pkg-config

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ $BUNDLE_PATH/ruby/*/cache

COPY . .

RUN chmod +x bin/* && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# 3. Etapa final optimizada
FROM base

COPY --from=build $BUNDLE_PATH $BUNDLE_PATH
COPY --from=build /rails /rails

# 4. Entrypoint mejorado
RUN echo "#!/bin/bash\n\
set -e\n\n\
# Verificación de PostgreSQL\n\
if [ -z \"\$DATABASE_URL\" ]; then\n\
  echo \"ERROR: DATABASE_URL no configurada. Render debe proveer esta variable automáticamente.\" >&2\n\
  echo \"Por favor, verifica que tienes un servicio PostgreSQL añadido en Render.\" >&2\n\
  exit 1\n\
fi\n\n\
# Esperar a PostgreSQL con timeout\n\
echo \"Verificando conexión a PostgreSQL en \$DATABASE_URL\"\n\
timeout 30s bash -c \"until pg_isready -d \$DATABASE_URL; do sleep 2; done\" || {\n\
  echo \"ERROR: No se pudo conectar a PostgreSQL\" >&2\n\
  exit 1\n\
}\n\n\
# Migraciones\n\
echo \"Ejecutando migraciones...\"\n\
./bin/rails db:prepare\n\n\
exec \"\$@\"" > /rails/bin/docker-entrypoint && \
    chmod +x /rails/bin/docker-entrypoint /rails/bin/*

# 5. Configuración de usuario
RUN useradd -r rails && \
    chown -R rails:rails /rails

USER rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]