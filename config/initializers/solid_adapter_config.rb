# Configure SolidQueue and SolidCache to use primary database connection instead of specialized ones
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Redirect SolidQueue to use the primary database
    if defined?(SolidQueue)
      # Disable the specialized database connection
      SolidQueue.instance_variable_set(:@connects_to, nil) if SolidQueue.instance_variable_defined?(:@connects_to)
    end
    
    # Redirect SolidCache to use the primary database or disable it
    if defined?(SolidCache)
      begin
        SolidCache.config.store = :null_store
        Rails.logger.info "SolidCache reconfigured to use null_store"
      rescue => e
        Rails.logger.error "Error configuring SolidCache: #{e.message}"
      end
    end
    
    # Log the configuration
    Rails.logger.info "Solid adapters reconfigured for simplified database usage"
  end
end 