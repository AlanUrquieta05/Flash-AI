# README

To start server
rails s

If not working use these commands first.
bundle install


If getting error about migration use,
rails db:migrate

## AI Flashcard Generation

The application uses OpenAI's API to generate flashcards. To enable this feature:

1. Copy `.env.sample` to `.env`
2. Add your OpenAI API key to the `.env` file:
   ```
   OPENAI_API_KEY=your_actual_api_key_here
   ```
3. Restart the server if it's already running

Alternatively, you can set the API key using Rails credentials:
```
rails credentials:edit --environment development
```

And add:
```yaml
openai_api_key: your_actual_api_key_here
```

## GitHub Codespace Permission Issues

If you encounter "permission denied" errors when running commands like `cucumber` in GitHub Codespaces, you have several options:

### Option 1: Use the setup script

```bash
# First make the script itself executable
chmod +x bin/setup_permissions

# Then run it to fix all permissions
./bin/setup_permissions
```

### Option 2: Create a new Codespace

New Codespaces will automatically run the setup script during creation.

### Option 3: Manual fix

If neither option works, run these commands manually:

```bash
# Make bin scripts executable
chmod +x bin/*

# Make cucumber executable
find vendor/bundle -name cucumber -type f -exec chmod +x {} \;
find vendor/bundle -path "*/bin/*" -type f -exec chmod +x {} \;

# Make bundler binstubs executable (if they exist)
if [ -d ".bundle/bin" ]; then chmod +x .bundle/bin/*; fi
```

These steps will fix executable permissions for all necessary files in the project.
