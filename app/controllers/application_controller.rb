class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :fix_csrf_for_deployed_environments
  
  private
  
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
