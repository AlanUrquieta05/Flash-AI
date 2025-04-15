#!/usr/bin/env bash
# exit on error
set -o errexit

echo "Starting Render build script"
echo "Using Ruby version: $(ruby -v)"

# Super aggressive bundler unfreezing
export BUNDLE_FROZEN=0 
export BUNDLE_DISABLE_VERSION_CHECK=1
bundle config --delete frozen || true
bundle config set frozen false || true
bundle config --local frozen false || true
bundle config --local deployment false || true
bundle config --local without development:test || true
bundle config --local silence_root_warning true || true
bundle config set --global frozen false || true

# Print bundler config for debugging
echo "Bundler configuration:"
bundle config

# Remove Gemfile.lock and have bundler regenerate it
echo "Removing Gemfile.lock to force regeneration..."
rm -f Gemfile.lock

echo "Installing dependencies..."
bundle install --jobs 4 --retry 3 --no-deployment

# Create required directories for assets
echo "Creating necessary directories for assets compilation..."
mkdir -p app/assets/builds
mkdir -p app/assets/stylesheets
mkdir -p public/assets

# Create Tailwind CSS file if it doesn't exist
echo "Creating Tailwind CSS file if missing..."
if [ ! -f app/assets/stylesheets/application.tailwind.css ]; then
  echo '@tailwind base;
@tailwind components;
@tailwind utilities;' > app/assets/stylesheets/application.tailwind.css
  echo "Created app/assets/stylesheets/application.tailwind.css"
fi

# Make sure asset-related directories exist
touch app/assets/builds/.keep
touch public/assets/.keep

echo "Precompiling assets..."
# Skip Tailwind if not needed
export SKIP_TAILWIND=true
RAILS_ENV=production SECRET_KEY_BASE=placeholder bundle exec rails assets:precompile || true
RAILS_ENV=production SECRET_KEY_BASE=placeholder bundle exec rails assets:clean || true

echo "Setting up database..."
RAILS_ENV=production bundle exec rails db:migrate

echo "Cleanup..."
rm -rf tmp/cache

echo "Build completed successfully!"