# Disable SolidCable in production to avoid database issues
if Rails.env.production? && defined?(SolidCable)
  Rails.application.config.to_prepare do
    if defined?(SolidCable)
      SolidCable.module_eval do
        def self.broadcast(channel, message)
          Rails.logger.info("SolidCable disabled in production: broadcast to #{channel} ignored")
        end
        
        def self.clear
          Rails.logger.info("SolidCable disabled in production: clear ignored")
        end
      end
    end
  end
  
  # Disable ActionCable server to avoid connection issues
  Rails.application.config.action_cable.mount_path = nil if defined?(ActionCable)
  
  # Log that we've disabled SolidCable
  Rails.logger.info "SolidCable disabled in production to avoid database issues"
end 