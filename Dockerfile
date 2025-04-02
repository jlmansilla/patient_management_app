# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Instala dependencias esenciales
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      libpq-dev \
      libjemalloc2 \
      libvips \
      git && \
    rm -rf /var/lib/apt/lists/*

# Variables de entorno para producción
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true

# Etapa de construcción
FROM base AS build

# Instala dependencias de construcción
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      pkg-config \
      libyaml-dev

# Instala gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ $BUNDLE_PATH/ruby/*/cache $BUNDLE_PATH/ruby/*/bundler/gems/*/.git

# Copia la aplicación
COPY . .

# Precompila assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Etapa final
FROM base

# Instala solo runtime dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libpq5 \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Copia artefactos desde la etapa de construcción
COPY --from=build $BUNDLE_PATH $BUNDLE_PATH
COPY --from=build /rails /rails

# Configura entrypoint
RUN echo "#!/bin/bash\n\
set -e\n\n\
# Verifica clave maestra\n\
if [ -z \"\$RAILS_MASTER_KEY\" ] && [ ! -f config/master.key ]; then\n\
  echo \"ERROR: RAILS_MASTER_KEY must be set\" >&2\n\
  exit 1\n\
fi\n\n\
# Ejecuta migraciones\n\
if [ \"\$RUN_MIGRATIONS\" = \"true\" ]; then\n\
  echo \"Running migrations...\"\n\
  ./bin/rails db:prepare\n\
fi\n\n\
exec \"\$@\"" > /rails/bin/docker-entrypoint && \
    chmod +x /rails/bin/docker-entrypoint

# Configura usuario no-root
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails /rails

USER rails:rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]