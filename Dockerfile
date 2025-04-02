# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Instala dependencias base
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      libpq5 \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Variables de entorno
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Etapa de construcción
FROM base AS build

# Dependencias de compilación
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      pkg-config

# Instala gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ $BUNDLE_PATH/ruby/*/cache

# Copia aplicación
COPY . .

# Establece permisos de ejecución
RUN chmod +x bin/rails bin/thrust

# Precompila assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Etapa final
FROM base

# Copia artefactos
COPY --from=build $BUNDLE_PATH $BUNDLE_PATH
COPY --from=build /rails /rails

# Configura entrypoint
RUN echo "#!/bin/bash\n\
set -e\n\n\
# Verifica credenciales\n\
if [ -z \"\$RAILS_MASTER_KEY\" ] && [ ! -f config/master.key ]; then\n\
  echo \"Error: RAILS_MASTER_KEY requerida\" >&2\n\
  exit 1\n\
fi\n\n\
# Ejecuta migraciones si es necesario\n\
if [ -n \"\$DATABASE_URL\" ] && [ \"\$SKIP_MIGRATIONS\" != \"true\" ]; then\n\
  echo \"Ejecutando migraciones...\"\n\
  ./bin/rails db:prepare\n\
fi\n\n\
exec \"\$@\"" > /rails/bin/docker-entrypoint && \
    chmod +x /rails/bin/docker-entrypoint

# Configura usuario y permisos
RUN useradd -m rails && \
    chown -R rails:rails /rails && \
    chmod 755 /rails/bin/*

USER rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]