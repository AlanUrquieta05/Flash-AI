#!/usr/bin/env bash
# exit on error
set -o errexit

echo "Starting Render build script"
echo "Using Ruby version: $(ruby -v)"

# Unfreeze bundler in a more robust way
export BUNDLE_FROZEN=0
export BUNDLE_DISABLE_VERSION_CHECK=1
bundle config --local frozen false
bundle config --local deployment false
bundle config --local without development:test
bundle config --local silence_root_warning true

echo "Installing dependencies..."
bundle install --jobs 4 --retry 3

echo "Precompiling assets..."
RAILS_ENV=production SECRET_KEY_BASE=placeholder bundle exec rails assets:precompile
RAILS_ENV=production SECRET_KEY_BASE=placeholder bundle exec rails assets:clean

echo "Setting up database..."
RAILS_ENV=production bundle exec rails db:migrate

echo "Cleanup..."
rm -rf tmp/cache

echo "Build completed successfully!"