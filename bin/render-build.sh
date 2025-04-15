#!/usr/bin/env bash
# exit on error
set -o errexit

echo "Starting Render build script"

# Unfreeze bundler in a more robust way
export BUNDLE_FROZEN=0
bundle config --local frozen false
bundle config --local deployment false
bundle config --local without development:test

echo "Installing dependencies..."
bundle install

echo "Precompiling assets..."
bundle exec rails assets:precompile RAILS_ENV=production
bundle exec rails assets:clean RAILS_ENV=production

echo "Setting up database..."
bundle exec rails db:migrate RAILS_ENV=production

echo "Cleanup..."
rm -rf tmp/cache

echo "Build completed successfully!"