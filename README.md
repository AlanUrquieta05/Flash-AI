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
