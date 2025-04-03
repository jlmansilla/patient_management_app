# Etapa 1: Construcción
FROM ruby:3.2 AS builder
# Configuración inicial
WORKDIR /app
ENV BUNDLE_PATH=/gems \
    BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true
# Copia Gemfile y Gemfile.lock
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4
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
    BUNDLE_PATH=/gems
# Copia las gemas preinstaladas
COPY --from=builder /gems /gems
COPY --from=builder /app /rails
# Instala dependencias del sistema (si es necesario)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libpq-dev postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Crear el script de entrada directamente
RUN echo '#!/bin/bash\nset -e\n\n# Ejecutar migraciones si es necesario\nif [ "${AUTO_MIGRATE}" = "true" ]; then\n  bundle exec rails db:migrate\nfi\n\n# Ejecutar el comando proporcionado\nexec "$@"' > /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Puerto de la aplicación
EXPOSE 3000
# Punto de entrada
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]