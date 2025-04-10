require 'net/http'
require 'json'
require 'csv'

class OpenAiService
  attr_reader :api_key, :api_base
  
  # System prompt from chat_client.rb
  SYSTEM_PROMPT = '''
    You are a the best flashcard generator.
    User Prompt: The user will provide a prompt for the flashcards they want to generate. And may include how many flashcards they want to generate.
    Your output: Generate flashcards in CSV format based on the users prompt. Each card should be on a new line.
    
Format: front,back
Important rules:
1. Do not use commas within the front or back text
2. Each line must have exactly one front and one back, separated by a single comma
3. First line must be the header: front,back
4. If the user provides how many flashcards they want, generate that many flashcards, otherwise generate 3 flashcards.
5. The front should be a term and the back should be a definition.
6. ALWAYS provide BOTH a front and back for EVERY card - the back must never be empty
7. The front is usually shorter (term/concept) and the back is longer (explanation/definition)
8. The definition on the back should be informative and educational - never leave it blank or minimal
9. VERY IMPORTANT: Return ONLY CSV format. Do not use markdown tables, do not use any formatting other than plain text CSV.
10. The very first line must be exactly "front,back" and all subsequent lines must follow that exact CSV format
'''
  
  def initialize(api_key = nil, api_base = nil)
    @api_key = api_key || Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY']
    @api_base = api_base || ENV['OPENAI_API_BASE'] || 'https://api.openai.com/v1'
  end
  
  def generate_flashcards(prompt)
    # Early return if no prompt provided
    return nil if prompt.blank?
    
    # Make API request to OpenAI
    response = make_request(prompt)
    
    # Parse the response and return the content
    if response && response["choices"] && response["choices"][0]["message"]["content"]
      content = response["choices"][0]["message"]["content"].strip
      
      # Log the full response content for debugging
      Rails.logger.info("FULL RESPONSE FROM OPENAI: #{content}")
      
      # Handle potential formats: sometimes AI returns a table-like format
      if content.include?('|') && !content.include?(',')
        Rails.logger.info("Detected table format - converting to CSV")
        # This might be a markdown table, convert to CSV
        csv_content = "front,back\n"
        content.split("\n").each do |line|
          if line.include?('|')
            parts = line.split('|').map(&:strip).reject(&:empty?)
            if parts.length >= 2 && !line.include?('-+-')
              front = parts[0].gsub(',', ' ')
              back = parts[1].gsub(',', ' ')
              csv_content += "#{front},#{back}\n" if front.present?
            end
          end
        end
        content = csv_content
        Rails.logger.info("Converted to CSV: #{content}")
      end
      
      # Ensure it's a properly formatted CSV with front,back header
      if !content.start_with?("front,back") && !content.start_with?("Front,Back")
        # Try to fix response that doesn't start with proper header
        Rails.logger.warn("Response doesn't start with proper CSV header")
        content = "front,back\n" + content
      end
      
      # Verify we have backs by parsing and checking
      begin
        parsed_data = CSV.parse(content, headers: true)
        
        # Check if any backs are missing (checking both uppercase and lowercase column names)
        has_empty_backs = parsed_data.any? do |row| 
          (row["back"].blank? && row["Back"].blank?) || 
          (row["back"].to_s.strip == "No definition provided" || row["Back"].to_s.strip == "No definition provided")
        end
        
        if has_empty_backs
          Rails.logger.warn("Some cards are missing 'back' content - trying to fix")
          
          # Fix CSV by ensuring each row has both front and back
          fixed_content = "front,back\n"
          parsed_data.each do |row|
            # Try both lowercase and uppercase headers
            front = (row["front"] || row["Front"])&.to_s&.strip
            back = (row["back"] || row["Back"])&.to_s&.strip
            
            if front.blank?
              front = "Empty Card"
            end
            
            if back.blank? || back == "No definition provided"
              # Generate a descriptive back using the front as context
              back = "This is a definition for #{front} that would normally be provided by the AI"
            end
            
            # Clean commas to avoid CSV issues
            front = front.gsub(',', ' ') if front
            back = back.gsub(',', ' ') if back
            
            fixed_content += "#{front},#{back}\n"
          end
          content = fixed_content
          Rails.logger.info("Fixed CSV to include backs for all cards. New content: #{content}")
        end
      rescue => e
        Rails.logger.error("Error parsing CSV response: #{e.message}")
        Rails.logger.error("Failed content was: #{content}")
        # Return dummy response as fallback
        return dummy_response["choices"][0]["message"]["content"]
      end
      
      return content
    end
    
    nil
  rescue => e
    Rails.logger.error("OpenAI API Error: #{e.message}")
    nil
  end
  
  private
  
  def make_request(prompt)
    # Return dummy data in development if no API key
    if Rails.env.development? && @api_key.blank?
      Rails.logger.info("Using dummy response for flash card generation")
      return dummy_response
    end
    
    Rails.logger.info("Making OpenAI API request to #{@api_base}/chat/completions")
    
    # Extract the base URI
    uri_str = @api_base.end_with?('/') ? "#{@api_base}chat/completions" : "#{@api_base}/chat/completions"
    uri = URI(uri_str)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 60 # Increase timeout for API calls
    
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"
    
    # Messages array following chat_client.rb approach
    messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: prompt }
    ]
    
    request.body = {
      model: "gpt-4o-mini", # Using the model from chat_client.rb
      messages: messages,
      temperature: 0.7
    }.to_json
    
    # Log request details (without sensitive info)
    Rails.logger.debug("Sending request to: #{uri}")
    
    # Send the request
    response = http.request(request)
    
    # Log response info
    Rails.logger.debug("Response status: #{response.code}")
    
    if response.code.to_i >= 400
      Rails.logger.error("OpenAI API error: #{response.code} - #{response.body}")
      return { "error" => response.body }
    end
    
    # Parse and return the response
    JSON.parse(response.body)
  end
  
  def dummy_response
    # For development without API key
    {
      "choices" => [
        {
          "message" => {
            "content" => "front,back
Mitochondria,Powerhouse of the cell that generates ATP through cellular respiration
Photosynthesis,Process by which plants convert light energy into chemical energy by using chlorophyll to capture sunlight
DNA,Molecule that carries genetic instructions for development and functioning of all known living organisms and many viruses
Cell membrane,Barrier that separates the interior of a cell from the external environment and controls what enters and exits
Nucleus,Control center of the cell containing genetic material and responsible for cell growth and reproduction"
          }
        }
      ]
    }
  end
end 