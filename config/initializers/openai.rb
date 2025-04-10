# config/initializers/openai.rb
# Load OpenAI API key from credentials
# 
# In development, you can set this in config/credentials/development.yml.enc using:
# rails credentials:edit --environment development
#
# Or use environment variables (preferred for production)

# Check if credentials has an openai_api_key
if !Rails.application.credentials.openai_api_key.present? && ENV['OPENAI_API_KEY'].present?
  # Use environment variable if credential not set
  Rails.application.credentials.openai_api_key = ENV['OPENAI_API_KEY'] 
end

# Log warning if no API key is found
unless Rails.application.credentials.openai_api_key.present?
  if Rails.env.development?
    Rails.logger.warn "No OpenAI API key found. Dummy data will be used for AI generation."
  else
    Rails.logger.error "No OpenAI API key found. AI generation will not work in #{Rails.env} environment."
  end
end 