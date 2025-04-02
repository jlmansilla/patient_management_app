# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. Instalación de dependencias (solo PostgreSQL)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libpq5 \
      postgresql-client \
      libvips && \
    apt-get purge -y sqlite3 && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development test" \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# 2. Etapa de construcción
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      pkg-config

COPY Gemfile Gemfile.lock ./
RUN bundle config set without 'development test sqlite' && \
    bundle install && \
    rm -rf ~/.bundle/ $BUNDLE_PATH/ruby/*/cache

COPY . .

# 3. Precompilación y permisos
RUN chmod +x bin/* && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# 4. Etapa final
FROM base

COPY --from=build $BUNDLE_PATH $BUNDLE_PATH
COPY --from=build /rails /rails

# 5. Entrypoint mejorado para PostgreSQL
RUN echo "#!/bin/bash\n\
set -e\n\n\
# Verificación de PostgreSQL\n\
if [ -z \"\$DATABASE_URL\" ]; then\n\
  echo \"ERROR: DATABASE_URL debe estar configurada\" >&2\n\
  echo \"Variables de entorno actuales:\" >&2\n\
  printenv | sort >&2\n\
  exit 1\n\
fi\n\n\
# Esperar a que PostgreSQL esté listo\n\
echo \"Verificando conexión a PostgreSQL...\"\n\
until pg_isready -d \$DATABASE_URL; do\n\
  sleep 2\n\
done\n\n\
# Migraciones\n\
echo \"Ejecutando migraciones...\"\n\
./bin/rails db:prepare\n\n\
exec \"\$@\"" > /rails/bin/docker-entrypoint && \
    chmod +x /rails/bin/docker-entrypoint /rails/bin/*

# 6. Configuración de usuario seguro
RUN groupadd -r rails && \
    useradd -r -g rails rails && \
    chown -R rails:rails /rails

USER rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]