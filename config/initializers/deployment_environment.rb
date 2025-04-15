# This file contains configuration to handle CSRF protection across different environments

# Check if we're running in a non-local environment (GitHub Codespaces, Render, etc.)
is_non_local_env = ENV['CODESPACES'] || 
                   ENV['GITHUB_CODESPACES'] || 
                   ENV['RENDER'] || 
                   ENV['HOSTNAME']&.include?('codespaces') ||
                   (ENV['GITHUB_REPOSITORY'] && ENV['GITHUB_SERVER_URL'])

# Determine allowed hosts based on environment
allowed_hosts = []
allowed_hosts << /.*\.app\.github\.dev/ if ENV['CODESPACES'] || ENV['GITHUB_CODESPACES']
allowed_hosts << /.*\.render\.com/ if ENV['RENDER']
allowed_hosts << /.*\.onrender\.com/
# Add any other deployment platforms as needed

Rails.application.configure do
  # Disable CSRF origin check to handle mismatches in all environments
  # This is safer than completely disabling CSRF protection
  if is_non_local_env || Rails.env.production?
    config.action_controller.forgery_protection_origin_check = false
    
    # For Render specifically, we set hosts = nil in production.rb,
    # so we need to skip adding hosts
    unless ENV['RENDER'] && Rails.env.production?
      # Allow hosts for various environments
      allowed_hosts.each do |host|
        config.hosts << host if config.hosts
      end
      
      # Add wildcard hosts in production to allow any domain (can be restricted later)
      if Rails.env.production? && config.hosts
        # Allow your app to be served from any domain in production
        # This should be replaced with your specific domains when known
        config.hosts.clear
      end
    end
    
    # Make sure CSRF protection is still enabled
    config.action_controller.allow_forgery_protection = true
  end
end

# Log the environment setup
Rails.logger.info "Running with flexible CSRF configuration for deployment environments" if is_non_local_env 