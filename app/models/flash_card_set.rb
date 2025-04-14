require 'csv'

class FlashCardSet < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :user_mail, presence: true
  validate :maximum_card_limit
  
  # Maximum number of cards allowed per set
  MAX_CARDS = 50
  
  # Maximum number of AI-generated cards per request
  MAX_AI_CARDS = 10
  
  # Custom validation for card limit
  def maximum_card_limit
    if cards.length > MAX_CARDS
      errors.add(:base, "A flashcard set cannot contain more than #{MAX_CARDS} cards")
    end
  end
  
  # Setters and getters for flashcards
  def cards
    return [] if flashcards.blank?
    
    # Return memoized result if available
    return @parsed_cards_array if @parsed_cards_array
    
    begin
      # First, try to detect and fix any obvious formatting issues
      content = flashcards.strip
      
      # Handle markdown tables once
      if content.include?('|') && !content.include?(',')
        content = convert_table_to_csv(content)
      end
      
      # Ensure proper header
      unless content.start_with?("front,back") || content.start_with?("Front,Back")
        content = "front,back\n" + content
      end
      
      # Parse CSV once
      parsed_csv = CSV.parse(content, headers: true)
      
      # Convert to array of hashes efficiently
      @parsed_cards_array = parsed_csv.map do |row|
        # Get front and back values, checking both lowercase and uppercase headers
        front = (row["front"] || row["Front"] || row.fields[0])&.to_s&.presence || "Empty Card"
        back = (row["back"] || row["Back"] || row.fields[1])&.to_s&.presence || "No definition available"
        
        { front: front, back: back }
      end
      
      return @parsed_cards_array
    rescue CSV::MalformedCSVError => e
      # Fall back to manual parsing
      @parsed_cards_array = fallback_csv_parse(content)
      return @parsed_cards_array
    rescue StandardError => e
      Rails.logger.error("Unexpected error in cards method: #{e.message}")
      return []
    end
  end
  
  # Separate method for converting table format to CSV
  def convert_table_to_csv(content)
    csv_content = "front,back\n"
    content.split("\n").each do |line|
      if line.include?('|') && !line.include?('-+-')
        parts = line.split('|').map(&:strip).reject(&:empty?)
        if parts.length >= 2
          front = parts[0].gsub(',', ' ')
          back = parts[1].gsub(',', ' ')
          csv_content += "#{front},#{back}\n" if front.present?
        end
      end
    end
    csv_content
  end
  
  # Fallback parsing method
  def fallback_csv_parse(content)
    cards = []
    lines = content.split("\n")
    # Skip header if it looks like a header
    start_index = lines.first&.include?(',') && (lines.first.downcase.include?('front') || lines.first.downcase.include?('back')) ? 1 : 0
    
    lines[start_index..-1].each do |line|
      parts = line.split(",", 2) # Split on first comma only
      if parts.size == 2
        cards << { front: parts[0].strip, back: parts[1].strip }
      elsif parts.size == 1 && parts[0].present?
        cards << { front: parts[0].strip, back: "No definition provided" }
      end
    end
    
    cards
  end
  
  def cards=(card_data)
    # Reset memoization
    @parsed_cards_array = nil
    
    return if card_data.blank?
    
    # Limit to MAX_CARDS
    if card_data.size > MAX_CARDS
      card_data = card_data.first(MAX_CARDS)
    end
    
    # Pre-filter empty cards before generating CSV
    valid_cards = card_data.reject { |card| card[:front].blank? && card[:back].blank? }
    
    # Use string building instead of CSV generation for better performance
    csv_lines = ["front,back"]
    valid_cards.each do |card|
      # Clean commas to avoid CSV format issues
      front = card[:front].to_s.gsub(',', ' ')
      back = card[:back].to_s.gsub(',', ' ')
      csv_lines << "#{front},#{back}"
    end
    
    self.flashcards = csv_lines.join("\n")
    self.length = valid_cards.size
  end
  
  # AI generation methods
  def generate_from_prompt(prompt, ai_service = nil)
    # Early validation of limits
    current_count = cards.length
    remaining_slots = MAX_CARDS - current_count
    
    if remaining_slots <= 0
      errors.add(:base, "Cannot generate more cards. Maximum limit of #{MAX_CARDS} cards reached.")
      return false
    end
    
    # Use provided service or create new one
    ai_service ||= OpenAiService.new
    
    # Generate flashcards
    csv_content = ai_service.generate_flashcards(prompt)
    return add_error_and_return_false("Failed to generate flashcards from prompt") if csv_content.blank?
    
    begin
      # Parse and limit the CSV content efficiently
      parsed_data = CSV.parse(csv_content, headers: true)
      
      # Apply limits - take the minimum of remaining slots, MAX_AI_CARDS, and parsed_data size
      max_cards_to_add = [remaining_slots, MAX_AI_CARDS, parsed_data.size].min
      
      # Check if we have valid cards to add
      if max_cards_to_add <= 0
        return add_error_and_return_false("No valid cards could be generated from the prompt")
      end
      
      # Take only the cards we need
      limited_rows = parsed_data.first(max_cards_to_add)
      
      # Convert to our card format
      new_cards = limited_rows.map do |row|
        {
          front: (row["front"] || row["Front"]).to_s.strip,
          back: (row["back"] || row["Back"]).to_s.strip
        }
      end
      
      # Filter out any invalid cards
      new_cards.reject! { |card| card[:front].blank? || card[:back].blank? }
      
      if new_cards.empty?
        return add_error_and_return_false("Generated cards had empty content")
      end
      
      # Add the new cards to existing ones
      all_cards = cards + new_cards
      self.cards = all_cards
      return true
    rescue => e
      Rails.logger.error("Error processing AI-generated cards: #{e.message}")
      return add_error_and_return_false("Error processing generated cards: #{e.message}")
    end
  end
  
  private
  
  def add_error_and_return_false(message)
    errors.add(:base, message)
    false
  end
  
  # Helper methods
  def add_card(front, back)
    # Skip empty cards
    return true if front.blank? && back.blank?
    
    # Check if adding a card would exceed the limit
    if cards.length >= MAX_CARDS
      errors.add(:base, "Maximum card limit of #{MAX_CARDS} reached")
      return false
    end
    
    # Clean up inputs
    front = front.to_s.strip
    back = back.to_s.strip
    
    # Add directly to the existing cards array
    current_cards = cards
    current_cards << { front: front, back: back }
    
    # Update the model
    self.cards = current_cards
    true
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
