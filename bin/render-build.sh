#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
bundle install

# Compile assets
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Setup database
bundle exec rails db:migrate

# Clear any lingering cache
rm -rf tmp/cache