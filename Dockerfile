# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

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

# Set executable permissions for required binaries
RUN chmod +x bin/rails bin/thrust

# Precompile bootsnap and assets
RUN bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage
FROM base

# Copy built artifacts
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Create entrypoint script as root
RUN echo "#!/bin/bash\nset -e\n\n# Wait for database if needed\nif [ \"\$WAIT_FOR_DB\" = \"true\" ]; then\n  echo \"Waiting for database...\"\n  until ./bin/rails db:version >/dev/null 2>&1; do\n    sleep 1\n  done\nfi\n\n# Check for credentials\nif [ -z \"\$RAILS_MASTER_KEY\" ] && [ ! -f config/master.key ]; then\n  echo \"ERROR: Either RAILS_MASTER_KEY must be set or config/master.key must exist\" >&2\n  echo \"Current environment variables:\" >&2\n  printenv | sort >&2\n  exit 1\nfi\n\nexec \"\$@\"" > /rails/bin/docker-entrypoint && \
    chmod +x /rails/bin/docker-entrypoint

# Create non-root user and set permissions
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp /rails/bin/docker-entrypoint /rails/bin/thrust

USER rails:rails

# Entrypoint prepares the database
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
