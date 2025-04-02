# syntax=docker/dockerfile:1

# This Dockerfile is designed for production, not development.
ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2" \
    RAILS_SERVE_STATIC_FILES="true" \
    RAILS_LOG_TO_STDOUT="true" \
    EDITOR="vi" \
    LANG="C.UTF-8" \
    JEMALLOC_ENABLED="1"

# Build stage
FROM base AS build

# Install build packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap and assets
RUN bundle exec bootsnap precompile app/ lib/ && \
    chmod +x bin/rails && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Verify thrust is available
RUN if [ ! -f ./bin/thrust ]; then echo "Thrust not found!"; exit 1; fi

# Final stage
FROM base

# Copy built artifacts
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Create entrypoint script as root
RUN echo "#!/bin/bash\nset -e\n\nif [ -z \"\$RAILS_MASTER_KEY\" ] && [ ! -f config/master.key ]; then\n  echo \"ERROR: RAILS_MASTER_KEY must be set or config/master.key must exist\" >&2\n  exit 1\nfi\n\nexec \"\$@\"" > /rails/bin/docker-entrypoint && \
    chmod +x /rails/bin/docker-entrypoint

# Create non-root user and set permissions
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp /rails/bin/docker-entrypoint

USER rails:rails

# Verify entrypoint
RUN /rails/bin/docker-entrypoint echo "Entrypoint test passed"

# Entrypoint prepares the database
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
