require 'csv'

class FlashCardSet < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :user_mail, presence: true
  
  # Setters and getters for flashcards
  def cards
    return [] if flashcards.blank?
    
    begin
      # First, try to detect and fix any obvious formatting issues
      content = flashcards.strip
      
      # Use memoization to avoid parsing CSV multiple times
      @parsed_cards ||= begin
        # If content looks like it has pipes instead of commas (markdown table)
        if content.include?('|') && !content.include?(',')
          fixed_content = "front,back\n"
          content.split("\n").each do |line|
            if line.include?('|')
              parts = line.split('|').map(&:strip).reject(&:empty?)
              if parts.length >= 2 && !line.include?('-+-')
                front = parts[0].gsub(',', ' ')
                back = parts[1].gsub(',', ' ')
                fixed_content += "#{front},#{back}\n" if front.present?
              end
            end
          end
          self.flashcards = fixed_content
          content = fixed_content
        end
        
        # Now parse the CSV
        CSV.parse(content, headers: true)
      end
      
      # Map rows to hash with fallbacks for missing values - use more efficient mapping
      headers = @parsed_cards.headers
      
      cards_array = @parsed_cards.map do |row|
        # Try both front/back and Front/Back headers - more efficiently
        front_val = row["front"] || row["Front"] || row.fields[0]
        back_val = row["back"] || row["Back"] || (row.fields.length > 1 ? row.fields[1] : nil)
        
        front = front_val.presence || "Empty Card"
        back = back_val.presence || "No definition available"
        
        { front: front, back: back }
      end
      
      return cards_array
    rescue CSV::MalformedCSVError => e
      # Fallback: try to manually parse by lines and looking for commas
      begin
        lines = flashcards.split("\n").drop(1) # Skip header
        cards = []
        
        lines.each do |line|
          parts = line.split(",", 2) # Split on first comma only
          if parts.size == 2
            cards << { front: parts[0].strip, back: parts[1].strip }
          elsif parts.size == 1 && parts[0].present?
            cards << { front: parts[0].strip, back: "No definition provided" }
          end
        end
        
        return cards unless cards.empty?
      rescue => fallback_error
        Rails.logger.error("Fallback parsing failed: #{fallback_error.message}")
      end
      
      [] # Return empty array if all parsing fails
    rescue StandardError => e
      Rails.logger.error("Unexpected error in cards method: #{e.message}")
      []
    end
  end
  
  def cards=(card_data)
    # Reset memoization
    @parsed_cards = nil
    
    return if card_data.blank?
    
    csv_data = CSV.generate do |csv|
      csv << ["front", "back"]
      card_data.each do |card|
        next if card[:front].blank? && card[:back].blank?
        csv << [card[:front], card[:back]]
      end
    end
    
    self.flashcards = csv_data
    self.length = card_data.count { |card| !card[:front].blank? || !card[:back].blank? }
  end
  
  # AI generation methods
  def generate_from_prompt(prompt, ai_service = nil)
    # This method will be implemented when AI service is ready
    # For now, it's a placeholder
    ai_service ||= OpenAiService.new
    csv_content = ai_service.generate_flashcards(prompt)
    
    if csv_content.present?
      self.flashcards = csv_content
      self.length = CSV.parse(csv_content, headers: true).count
      return true
    else
      errors.add(:base, "Failed to generate flashcards from prompt")
      return false
    end
  end
  
  # Helper methods
  def add_card(front, back)
    new_cards = cards
    new_cards << { front: front, back: back }
    self.cards = new_cards
  end
  
  def empty?
    length.nil? || length.zero?
  end
  
  # Import/export methods
  def self.import_from_csv(csv_data, user_mail)
    return nil if csv_data.blank?
    
    name = File.basename(csv_data.original_filename, ".*") if csv_data.respond_to?(:original_filename)
    name ||= "Imported Set #{Time.now.strftime('%Y-%m-%d')}"
    
    set = FlashCardSet.new(name: name, user_mail: user_mail)
    begin
      content = csv_data.read
      set.flashcards = content
      set.length = CSV.parse(content, headers: true).count
      set.save ? set : nil
    rescue => e
      # Log the error and return nil
      Rails.logger.error("Error importing CSV: #{e.message}")
      nil
    end
  end
end
