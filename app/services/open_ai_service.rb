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
11. MOST IMPORTANT: If the user provides existing flashcards, make sure to use them to generate new flashcards do not repeat any existing cards.
12. LIMIT: Generate AT MOST 10 flashcards, even if the user asks for more.
13. No matter what the user asks for try your best to generate flashcards for that topic. Unless it is not possible to generate flashcards for that topic or is unethical.
14. IMPORTANT: DO NOT include "Front:" or "Back:" in your content. Just provide the term and definition directly.
'''
  
  # System prompt for test question generation
  TEST_PROMPT = '''
    You are an expert educational test creator specializing in multiple-choice questions.
    
    User Prompt: The user will provide flash card terms and definitions, and you need to create multiple-choice questions.
    
    Your output: Generate high-quality test questions in the specified format.
    
    Important rules:
    1. Each question must be multiple-choice with exactly 4 options (A, B, C, D)
    2. ALWAYS place the correct answer (the actual definition from the flash card) as option A
    3. Create 3 plausible but incorrect alternative answers (B, C, D) that are:
       a. Similar in length and style to the correct answer
       b. Semantically related to the topic but factually incorrect
       c. Not obviously wrong or absurd - they should require thought to identify as incorrect
    4. Mix strategies for creating incorrect options:
       - Use definitions of related terms
       - Introduce subtle errors or misconceptions
       - Reverse cause and effect relationships
       - Include partially correct information with critical flaws
    5. Include a detailed explanation of why the correct answer is right and why each incorrect option is wrong
    6. Follow the exact format requested in the prompt
    7. Create one test question for EVERY term provided - ensure complete coverage
    8. Focus on testing understanding of concepts, not just rote memorization
  '''
  
  def initialize(api_key = nil, api_base = nil)
    @api_key = api_key || Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY']
    @api_base = api_base || ENV['OPENAI_API_BASE'] || 'https://api.openai.com/v1'
  end
  
  def generate_flashcards(prompt)
    # Early return if no prompt provided
    return nil if prompt.blank?
    
    # Get existing cards from database
    existing_cards = get_existing_cards
    
    # Make API request to OpenAI
    response = make_request(prompt, existing_cards)
    
    # Parse the response and return the content
    if response && response["choices"] && response["choices"][0]["message"]["content"]
      content = response["choices"][0]["message"]["content"].strip
      
      # Handle potential formats: sometimes AI returns a table-like format
      if content.include?('|') && !content.include?(',')
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
      end
      
      # Ensure it's a properly formatted CSV with front,back header
      if !content.start_with?("front,back") && !content.start_with?("Front,Back")
        # Try to fix response that doesn't start with proper header
        content = "front,back\n" + content
      end
      
      # Verify we have backs by parsing and checking
      begin
        parsed_data = CSV.parse(content, headers: true)
        
        # Clean up Front:/Back: prefixes from generated content
        clean_content = "front,back\n"
        parsed_data.each do |row|
          front = (row["front"] || row["Front"])&.to_s&.strip || ""
          back = (row["back"] || row["Back"])&.to_s&.strip || ""
          
          # Remove Front:/Back: prefixes if they exist
          front = front.sub(/^Front:\s*/i, "")
          back = back.sub(/^Back:\s*/i, "")
          
          # Clean commas
          front = front.gsub(',', ' ')
          back = back.gsub(',', ' ')
          
          clean_content += "#{front},#{back}\n" if front.present?
        end
        
        content = clean_content
        parsed_data = CSV.parse(content, headers: true)
        
        # Check if any backs are missing (checking both uppercase and lowercase column names)
        has_empty_backs = parsed_data.any? do |row| 
          (row["back"].blank? && row["Back"].blank?) || 
          (row["back"].to_s.strip == "No definition provided" || row["Back"].to_s.strip == "No definition provided")
        end
        
        if has_empty_backs
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
        end
      rescue => e
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
  
  def generate_test_questions(prompt)
    # Early return if no prompt provided
    return nil if prompt.blank?
    
    # Log the prompt for debugging
    Rails.logger.info("Generating test questions with prompt: #{prompt[0..100]}...")
    
    # Make API request to OpenAI - use the same make_request method as for flashcards
    # since make_test_request might not be available
    response = make_request(prompt, "", TEST_PROMPT)
    
    # Parse the response and return the content
    if response && response["choices"] && response["choices"][0]["message"]["content"]
      return response["choices"][0]["message"]["content"].strip
    end
    
    # Return dummy data in development for testing
    if Rails.env.development? 
      Rails.logger.info("Using dummy test response in development")
      return dummy_test_response["choices"][0]["message"]["content"]
    end
    
    nil
  rescue => e
    Rails.logger.error("OpenAI API Error (test questions): #{e.message}")
    # Return dummy data if there's an error
    if Rails.env.development?
      return dummy_test_response["choices"][0]["message"]["content"]
    end
    nil
  end
  
  private
  
  def get_existing_cards
    return "" unless defined?(FlashCardSet)
    
    # Get all cards from all flashcard sets
    existing_cards = ""
    
    # Add header for reference
    existing_cards += "Existing Flashcards (Do not repeat these):\n"
    
    # Fetch all flashcard sets from database
    FlashCardSet.all.each do |set|
      cards = set.cards
      next if cards.empty?
      
      # Add each card to the existing_cards string with a format that won't be confused with content
      cards.each do |card|
        # Skip cards with empty content
        next if card[:front].blank? || card[:back].blank?
        
        # Format without "Front:" and "Back:" prefixes that could be confused with content
        existing_cards += "- Term: \"#{card[:front]}\" | Definition: \"#{card[:back]}\"\n"
      end
    end
    
    existing_cards
  end
  
  def make_request(prompt, existing_cards = "", system_prompt = SYSTEM_PROMPT)
    # Return dummy data in development if no API key
    if Rails.env.development? && @api_key.blank?
      return dummy_response if system_prompt == SYSTEM_PROMPT
      return dummy_test_response if system_prompt == TEST_PROMPT
    end
    
    # Extract the base URI
    uri_str = @api_base.end_with?('/') ? "#{@api_base}chat/completions" : "#{@api_base}/chat/completions"
    uri = URI(uri_str)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 60 # Increase timeout for API calls
    http.open_timeout = 10 # Add open timeout to prevent long connection waits
    
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"
    
    # Combine the existing cards with the user prompt
    full_prompt = prompt
    if existing_cards.present?
      full_prompt = "#{existing_cards}\n\nGenerate new flashcards for: #{prompt}\n\nRemember to generate AT MOST 10 flashcards."
    else
      full_prompt = "#{prompt}\n\nRemember to generate AT MOST 10 flashcards."
    end
    
    # Messages array following chat_client.rb approach
    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: full_prompt }
    ]
    
    request.body = {
      model: "gpt-4o-mini", # Using the model from chat_client.rb
      messages: messages,
      temperature: 0.7
    }.to_json
    
    # Send the request
    response = http.request(request)
    
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
  
  def dummy_test_response
    # For development without API key - provide a high-quality example
    {
      "choices" => [
        {
          "message" => {
            "content" => "Question #1: What is the primary function of mitochondria in a cell?
A. Mitochondria are cellular organelles that generate energy through the process of cellular respiration, converting nutrients into ATP.
B. Mitochondria are responsible for protein synthesis by translating mRNA into amino acid chains.
C. Mitochondria store genetic material and regulate gene expression in eukaryotic cells.
D. Mitochondria coordinate cell division and ensure proper chromosome segregation during mitosis.

Correct: A
Explanation: Mitochondria are often called the powerhouse of the cell because their main function is to generate energy in the form of ATP through cellular respiration. Option B describes the function of ribosomes, not mitochondria. Option C refers to the nucleus's role in the cell. Option D describes the function of the centrosome and mitotic spindle.

Question #2: What is photosynthesis?
A. Photosynthesis is the process by which green plants and certain other organisms convert light energy into chemical energy, using carbon dioxide and water to produce glucose and oxygen.
B. Photosynthesis is the process by which plants break down glucose into carbon dioxide and water to release energy for cellular activities.
C. Photosynthesis is a type of cellular respiration that occurs in plant cells during nighttime to maintain metabolic functions.
D. Photosynthesis is the mechanism plants use to absorb minerals and nutrients from soil through their root systems.

Correct: A
Explanation: Photosynthesis is correctly defined in option A as the process that converts light energy into chemical energy (glucose), using carbon dioxide and water as inputs and producing oxygen as a byproduct. Option B describes cellular respiration, not photosynthesis. Option C incorrectly suggests photosynthesis occurs at night and is a form of respiration. Option D describes the function of roots in nutrient absorption, not photosynthesis.

Question #3: What molecule carries genetic instructions for all known living organisms?
A. DNA (Deoxyribonucleic Acid) is the molecule that contains the genetic instructions used in the development and functioning of all known living organisms.
B. RNA is the primary genetic material that stores and transmits hereditary information in all cellular organisms.
C. Proteins are the molecules that contain and preserve genetic information across generations in living systems.
D. ATP is the complex molecule that encodes genetic information and controls inheritance patterns in organisms.

Correct: A
Explanation: DNA (Deoxyribonucleic Acid) is the molecule that carries genetic instructions for development, functioning, growth, and reproduction of all known living organisms, as correctly stated in option A. Option B is incorrect because while RNA plays important roles in gene expression, DNA is the primary genetic material in nearly all organisms. Option C is wrong because proteins are the products of gene expression, not carriers of genetic information. Option D is incorrect because ATP is an energy-carrying molecule, not genetic material."
          }
        }
      ]
    }
  end
end 