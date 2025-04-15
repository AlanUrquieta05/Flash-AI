# Check if critical tables exist at application startup
if Rails.env.production?
  Rails.application.config.after_initialize do
    begin
      # Check if database is accessible
      ActiveRecord::Base.connection.execute("SELECT 1")
      
      # Check if tables exist and create them if they don't
      tables_exist = ActiveRecord::Base.connection.table_exists?(:users) &&
                    ActiveRecord::Base.connection.table_exists?(:sessions) &&
                    ActiveRecord::Base.connection.table_exists?(:flash_card_sets)
                    
      unless tables_exist
        Rails.logger.warn "Critical tables missing. Attempting to create them on startup..."
        
        # Execute the rake task
        Rails.application.load_tasks
        Rake::Task["db:force_create_tables"].invoke
      end
    rescue => e
      Rails.logger.error "Database check at startup failed: #{e.message}"
    end
  end
end 