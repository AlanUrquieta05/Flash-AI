# Skip Tailwind CSS configuration in certain environments or if explicitly set
if ENV['SKIP_TAILWIND'] == 'true' || Rails.env.production?
  # Disable the Tailwind compiler in production or when skipped
  Rails.application.config.assets.tailwind.compile = false if Rails.application.config.respond_to?(:assets) && 
                                                              Rails.application.config.assets.respond_to?(:tailwind)
  
  # Add a message to the logs
  Rails.logger.info "Tailwind CSS compilation disabled due to SKIP_TAILWIND=true or production environment"
end

# Create necessary directories for assets if they don't exist
Rails.application.config.after_initialize do
  %w[
    app/assets/builds
    app/assets/stylesheets
    public/assets
  ].each do |dir|
    path = Rails.root.join(dir)
    FileUtils.mkdir_p(path) unless Dir.exist?(path)
  end
  
  # Ensure application.tailwind.css exists
  tailwind_css_path = Rails.root.join('app/assets/stylesheets/application.tailwind.css')
  unless File.exist?(tailwind_css_path)
    File.write(tailwind_css_path, <<~CSS)
      @tailwind base;
      @tailwind components;
      @tailwind utilities;
    CSS
  end
end 