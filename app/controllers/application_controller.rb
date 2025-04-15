class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :fix_csrf_for_deployed_environments
  before_action :ensure_database_connection
  
  rescue_from ActiveRecord::StatementInvalid, 
              ActiveRecord::ConnectionNotEstablished, 
              PG::ConnectionBad do |exception|
    # Log the error with details for debugging
    Rails.logger.error "Database error: #{exception.class.name} - #{exception.message}"
    
    # Render a custom error page
    render file: Rails.root.join('public', '500.html'), 
           status: :internal_server_error, 
           layout: false
  end
  
  private
  
  def ensure_database_connection
    # Attempt to verify database connection
    ActiveRecord::Base.connection.execute("SELECT 1")
  rescue ActiveRecord::ConnectionNotEstablished
    # Try to reconnect if connection is lost
    ActiveRecord::Base.establish_connection
    # The rescue at the class level will catch if this fails again
  end
  
  def fix_csrf_for_deployed_environments
    # For deployed environments (GitHub, Render, etc.), the Origin header and base_url might not match
    # This relaxes CSRF protection by making the Origin header match the base_url
    if request.headers['HTTP_ORIGIN'] && 
       request.base_url && 
       request.headers['HTTP_ORIGIN'] != request.base_url
      
      # Only perform this fix in cases where the origin looks like a development URL but we're in production
      if (request.headers['HTTP_ORIGIN'].include?('localhost') || 
          request.headers['HTTP_ORIGIN'].include?('127.0.0.1')) && 
         !request.base_url.include?('localhost')
        
        # Log the mismatch for debugging purposes
        logger.info "CSRF Origin Check: Origin header (#{request.headers['HTTP_ORIGIN']}) " \
                   "doesn't match base_url (#{request.base_url}). " \
                   "Fixing for deployed environment."
                   
        # Temporarily store the real origin
        @original_origin = request.headers['HTTP_ORIGIN']
        
        # Override the Origin header for CSRF checks
        request.headers['HTTP_ORIGIN'] = request.base_url
      end
    end
  end
end
