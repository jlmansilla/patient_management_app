# Etapa 1: Construcción
FROM ruby:3.2 AS builder
# Configuración inicial
WORKDIR /app

# Copia Gemfile y Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Instala solo las gemas de producción
ENV BUNDLE_WITHOUT=development:test
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true

# Instala las gemas
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4

# Copia el resto de la aplicación
COPY . .

# Precompila los assets
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# Etapa 2: Ejecución
FROM ruby:3.2-slim
# Configuración inicial
WORKDIR /rails
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    BUNDLE_WITHOUT=development:test

# Instala dependencias del sistema
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libpq-dev postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copia las gemas preinstaladas y la aplicación
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /rails

# Crear el script de entrada
RUN echo '#!/bin/bash\nset -e\n\n# Ejecutar migraciones si es necesario\nif [ "${AUTO_MIGRATE}" = "true" ]; then\n  bundle exec rails db:migrate\nfi\n\n# Ejecutar el comando proporcionado\nexec "$@"' > /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Puerto de la aplicación
EXPOSE 3000

# Punto de entrada
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]