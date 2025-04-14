class FlashCardSetsController < ApplicationController
  before_action :set_flash_card_set, only: %i[ show edit update destroy toggle_favorite test ]

  # GET /flash_card_sets or /flash_card_sets.json
  def index
    @flash_card_sets = FlashCardSet.where(user_mail: current_user.email_address)
                                  .select(:id, :name, :user_mail, :length, :favorite)
                                  .order(updated_at: :desc)
  end

  # GET /flash_card_sets/1 or /flash_card_sets/1.json
  def show
    authorize_user_access!
    
    # Log info for debugging
    Rails.logger.debug("Accessing FlashCardSet ##{@flash_card_set.id} in format: #{request.format}")
    
    # Use eager loading for associated data if needed
    respond_to do |format|
      format.html # show.html.erb
      format.json do
        # Ensure cards are properly serialized
        Rails.logger.debug("Rendering JSON with #{@flash_card_set.cards.count} cards")
        render :show
      end
    end
  end

  # GET /flash_card_sets/new
  def new
    @flash_card_set = FlashCardSet.new(user_mail: current_user.email_address)
  end

  # GET /flash_card_sets/1/edit
  def edit
    authorize_user_access!
  end

  # POST /flash_card_sets or /flash_card_sets.json
  def create
    @flash_card_set = FlashCardSet.new(flash_card_set_params)
    @flash_card_set.user_mail = current_user.email_address
    
    # Handle cards data if it's present
    if params[:flash_card_set][:cards].present?
      begin
        if params[:flash_card_set][:cards].is_a?(Array)
          # Direct array from fetch API (already parsed by Rails)
          Rails.logger.info("Using cards array directly: #{params[:flash_card_set][:cards].size} cards")
          @flash_card_set.cards = params[:flash_card_set][:cards]
        else
          # String that needs parsing
          Rails.logger.info("Parsing cards from JSON string")
          cards_data = JSON.parse(params[:flash_card_set][:cards])
          @flash_card_set.cards = cards_data
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Error parsing cards JSON: #{e.message}")
        @flash_card_set.errors.add(:base, "Invalid card data format")
        
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @flash_card_set.errors, status: :unprocessable_entity }
        end
        return
      rescue => e
        Rails.logger.error("Unexpected error processing cards: #{e.message}")
        @flash_card_set.errors.add(:base, "Error processing cards: #{e.message}")
        
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @flash_card_set.errors, status: :unprocessable_entity }
        end
        return
      end
    end

    respond_to do |format|
      if @flash_card_set.save
        format.html { redirect_to flash_card_sets_path, notice: "Flash card set was successfully created." }
        format.json { render :show, status: :created, location: @flash_card_set }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @flash_card_set.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /flash_card_sets/1 or /flash_card_sets/1.json
  def update
    authorize_user_access!
    
    # Handle cards data based on whether it comes from JSON or form data
    if params[:flash_card_set] && params[:flash_card_set][:cards].present?
      if params[:flash_card_set][:cards].is_a?(Array)
        # Direct JSON format from fetch API
        @flash_card_set.cards = params[:flash_card_set][:cards]
        update_params = flash_card_set_params.except(:cards)
      elsif params[:flash_card_set][:cards].is_a?(String)
        # Form-encoded or JSON string that needs parsing
        begin
          cards_data = JSON.parse(params[:flash_card_set][:cards])
          @flash_card_set.cards = cards_data
          update_params = flash_card_set_params.except(:cards)
        rescue JSON::ParserError => e
          Rails.logger.error("Error parsing cards JSON: #{e.message}")
          @flash_card_set.errors.add(:base, "Invalid card data format")
          
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_entity }
            format.json { render json: @flash_card_set.errors, status: :unprocessable_entity }
          end
          return
        end
      else
        update_params = flash_card_set_params
      end
    else
      update_params = flash_card_set_params
    end

    respond_to do |format|
      if @flash_card_set.update(update_params)
        format.html { redirect_to flash_card_sets_path, notice: "Flash card set was successfully updated." }
        format.json { render :show, status: :ok, location: @flash_card_set }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @flash_card_set.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /flash_card_sets/1 or /flash_card_sets/1.json
  def destroy
    authorize_user_access!
    @flash_card_set.destroy!

    respond_to do |format|
      format.html { redirect_to flash_card_sets_path, status: :see_other, notice: "Flash card set was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # PATCH /flash_card_sets/1/toggle_favorite
  def toggle_favorite
    authorize_user_access!
    @flash_card_set.update(favorite: !@flash_card_set.favorite)
    
    respond_to do |format|
      format.html { redirect_to flash_card_sets_path }
      format.json { render :show, status: :ok, location: @flash_card_set }
    end
  end

  # POST /flash_card_sets/generate
  def generate
    # Extract prompt and validate
    @prompt = extract_prompt_from_params
    
    unless @prompt.present?
      respond_with_error("Prompt cannot be empty")
      return
    end
    
    # Log the request
    Rails.logger.info("Generating flash cards for prompt: #{@prompt[0..50]}...")
    
    # Create a service instance and generate cards
    ai_service = OpenAiService.new
    csv_content = ai_service.generate_flashcards(@prompt)
    
    if csv_content.blank?
      respond_with_error("Failed to generate cards from the given prompt")
      return
    end
    
    # Process the generated cards
    begin
      # Parse and validate CSV content
      parsed_data = CSV.parse(csv_content, headers: true)
      
      # Apply card limit
      if parsed_data.size > FlashCardSet::MAX_AI_CARDS
        Rails.logger.info("Limiting AI-generated cards to #{FlashCardSet::MAX_AI_CARDS}")
        parsed_data = limit_and_format_cards(parsed_data, FlashCardSet::MAX_AI_CARDS)
      end
      
      # Create and save the flash card set
      @flash_card_set = create_flash_card_set_from_csv(parsed_data)
      
      if @flash_card_set.persisted?
        respond_with_success
      else
        respond_with_error("Failed to save generated flash cards: #{@flash_card_set.errors.full_messages.join(', ')}")
      end
    rescue => e
      Rails.logger.error("Error processing generated cards: #{e.message}")
      respond_with_error("An error occurred while processing generated cards")
    end
  rescue => e
    Rails.logger.error("Exception in generate action: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    respond_with_error("An unexpected error occurred. Please try again later.")
  end

  # GET /flash_card_sets/1/test
  def test
    authorize_user_access!
    
    # Log that we entered the test action
    Rails.logger.info("=== ENTERED TEST ACTION for flash card set #{@flash_card_set.id} ===")
    
    # Check if the set has cards
    if @flash_card_set.cards.blank?
      Rails.logger.warn("Flash card set #{@flash_card_set.id} has no cards")
      redirect_to flash_card_set_path(@flash_card_set), alert: "Cannot create a test for an empty flash card set."
      return
    end
    
    begin
      # Initialize OpenAI service
      ai_service = OpenAiService.new
      
      # Generate test questions using the flash card data
      @test_questions = generate_test_questions(ai_service)
      
      # If we couldn't generate test questions, use the dummy generator as fallback
      if @test_questions.blank?
        Rails.logger.warn("OpenAI API failed to generate test questions, using fallback generator")
        @test_questions = dummy_test_questions
      end
      
      # If we still couldn't generate test questions, redirect with an error message
      if @test_questions.blank?
        Rails.logger.error("Failed to generate test questions for flash card set #{@flash_card_set.id}")
        redirect_to flash_card_set_path(@flash_card_set), alert: "Failed to generate test questions. Please try again later."
        return
      end
      
      Rails.logger.info("Successfully generated #{@test_questions.size} test questions")
      
      # Render the test view
      respond_to do |format|
        format.html # test.html.erb
        format.json { render json: { questions: @test_questions } }
      end
    rescue => e
      Rails.logger.error("Error in test action: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to flash_card_set_path(@flash_card_set), alert: "An error occurred while generating the test: #{e.message}"
      return
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flash_card_set
      @flash_card_set = FlashCardSet.find(params[:id])
      # Cache cards result to avoid repeated CSV parsing
      @flash_card_set.cards if params[:action] == 'show'
    end

    # Only allow a list of trusted parameters through.
    def flash_card_set_params
      if params[:flash_card_set] && params[:flash_card_set][:cards].present? && params[:flash_card_set][:cards].is_a?(Array)
        # If cards is already an array, we need to permit all its attributes
        params.require(:flash_card_set).permit(:name, :flashcards, :length, :favorite, cards: [:front, :back])
      else
        params.require(:flash_card_set).permit(:name, :flashcards, :length, :favorite, :cards)
      end
    end

    def authorize_user_access!
      unless @flash_card_set.user_mail == current_user.email_address
        redirect_to flash_card_sets_path, alert: "You are not authorized to access this flash card set."
      end
    end

    # Extract prompt from various possible parameter formats
    def extract_prompt_from_params
      prompt = params[:prompt].presence || params.dig(:flash_card_set, :prompt).presence
      
      # Check for prompt from plain JSON
      if prompt.nil? && request.content_type =~ /json/i
        body = request.body.read
        json_params = JSON.parse(body) rescue nil
        prompt = json_params["prompt"] if json_params
      end
      
      prompt
    end
    
    # Process and limit cards to the specified max
    def limit_and_format_cards(parsed_data, max_cards)
      limited_csv = CSV.generate do |csv|
        csv << ["front", "back"]
        parsed_data.first(max_cards).each do |row|
          front = (row["front"] || row["Front"])&.to_s
          back = (row["back"] || row["Back"])&.to_s
          csv << [front, back] if front.present? && back.present?
        end
      end
      
      CSV.parse(limited_csv, headers: true)
    end
    
    # Create a new flash card set with the CSV content
    def create_flash_card_set_from_csv(parsed_data)
      set_name = @prompt.truncate(30, omission: '...')
      
      # Convert parsed data to CSV string
      csv_content = CSV.generate do |csv|
        csv << ["front", "back"]
        parsed_data.each do |row|
          front = (row["front"] || row["Front"])&.to_s&.strip
          back = (row["back"] || row["Back"])&.to_s&.strip
          
          # Fix empty backs
          if back.blank? || back == "No definition provided"
            back = "This term refers to #{front} and is an important concept in this subject area."
          end
          
          # Clean commas
          front = front.gsub(',', ' ') if front
          back = back.gsub(',', ' ') if back
          
          csv << [front, back] if front.present?
        end
      end
      
      # Create and save the set
      flash_card_set = FlashCardSet.new(
        name: set_name,
        user_mail: current_user.email_address,
        flashcards: csv_content
      )
      
      flash_card_set.length = parsed_data.size
      flash_card_set.save
      flash_card_set
    end
    
    # Respond with error in appropriate format
    def respond_with_error(message)
      respond_to do |format|
        format.html { 
          flash[:alert] = message
          redirect_to flash_card_sets_path
        }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
    end
    
    # Respond with success in appropriate format
    def respond_with_success
      respond_to do |format|
        format.html { redirect_to flash_card_set_path(@flash_card_set), notice: "Flash cards successfully generated" }
        format.json { 
          render json: { 
            success: true, 
            message: "Flash cards successfully generated", 
            redirect_url: flash_card_set_path(@flash_card_set),
            id: @flash_card_set.id
          }
        }
      end
    end

    # Generate multiple-choice test questions for each card in the set
    def generate_test_questions(ai_service)
      # Prepare the set's cards for the prompt
      cards_data = @flash_card_set.cards.map { |card| "Term: #{card[:front]}, Definition: #{card[:back]}" }.join("\n")
      
      # Create the prompt for the AI
      prompt = <<~PROMPT
        Generate multiple-choice test questions based on these flash cards.
        
        IMPORTANT: Create one question for EACH of the following flashcards:
        
        #{cards_data}
        
        For each term, create a multiple-choice question with 4 options (A, B, C, D).
        The correct answer should be the definition from the flash card.
        The other options should be plausible but incorrect alternatives.
        
        Format each question as follows:
        Question #: [Question asking for the definition of the term]
        A. [Correct answer - the actual definition from the flashcard]
        B. [Plausible but incorrect answer]
        C. [Plausible but incorrect answer]
        D. [Plausible but incorrect answer]
        Correct: A
        Explanation: [Brief explanation of why the answer is correct]
        
        Create one question for EVERY term in the list - do not skip any flashcards.
      PROMPT
      
      # Make the API request
      response = ai_service.generate_test_questions(prompt)
      
      # Parse the response to extract questions
      questions = parse_test_questions(response)
      
      # If we don't have questions for all cards, generate dummy questions
      if questions.size < @flash_card_set.cards.size
        Rails.logger.warn("Not enough questions generated (#{questions.size} vs #{@flash_card_set.cards.size} cards). Filling with dummy questions.")
        
        # Find cards that don't have questions
        existing_questions = questions.map { |q| q[:question] }
        missing_cards = @flash_card_set.cards.reject do |card|
          existing_questions.any? { |q| q.include?(card[:front]) }
        end
        
        # Generate better questions for the missing cards
        dummy_questions = missing_cards.map do |card|
          term = card[:front]
          definition = card[:back]
          
          # Generate plausible incorrect answers
          incorrect_answers = generate_plausible_incorrect_answers(term, definition, @flash_card_set.cards)
          
          # Create a proper explanation
          explanation = "The correct definition of '#{term}' is '#{definition}'. This is the accurate description as shown in the flashcard. The other options contain elements that might seem plausible but are not correct in this context."
          
          {
            question: "What is the correct definition of '#{term}'?",
            options: [
              { letter: "A", text: definition },
              { letter: "B", text: incorrect_answers[0] },
              { letter: "C", text: incorrect_answers[1] },
              { letter: "D", text: incorrect_answers[2] }
            ],
            correct: "A",
            explanation: explanation
          }
        end
        
        # Add the dummy questions to the AI-generated ones
        questions.concat(dummy_questions)
      end
      
      questions
    end
    
    # Parse the AI response into structured test questions
    def parse_test_questions(response)
      return [] if response.blank?
      
      questions = []
      current_question = nil
      
      response.split("\n").each do |line|
        line = line.strip
        
        if line.start_with?("Question #") || line.match?(/^[\d]+\./)
          # Save the previous question if it exists
          questions << current_question if current_question
          
          # Start a new question
          current_question = {
            question: line.sub(/^Question #\s*\d*:\s*/, '').sub(/^[\d]+\.\s*/, ''),
            options: [],
            correct: nil,
            explanation: nil
          }
        elsif line.match?(/^[A-D]\./) && current_question
          # Add an option to the current question
          option_letter = line[0]
          option_text = line[2..-1].strip
          
          if option_text.present?
            current_question[:options] << { letter: option_letter, text: option_text }
          end
        elsif line.start_with?("Correct:") && current_question
          # Extract the correct answer
          current_question[:correct] = line.sub("Correct:", "").strip
        elsif line.start_with?("Explanation:") && current_question
          # Extract the explanation
          current_question[:explanation] = line.sub("Explanation:", "").strip
        elsif current_question && current_question[:explanation] && line.strip.present?
          # Append to the explanation if we're already in an explanation section
          current_question[:explanation] += " " + line.strip
        end
      end
      
      # Add the last question if it exists
      questions << current_question if current_question
      
      # Ensure correct formatting for all questions
      questions.each do |question|
        # If we don't have a correct answer marked, assume it's A
        question[:correct] = "A" if question[:correct].blank?
        
        # If we don't have an explanation, create one
        if question[:explanation].blank?
          term = question[:question].scan(/'([^']+)'/).flatten.first
          correct_option = question[:options].find { |opt| opt[:letter] == question[:correct] }
          
          if term && correct_option
            question[:explanation] = "The correct definition of '#{term}' is '#{correct_option[:text]}'. This is the accurate description as shown in the flashcard."
          else
            question[:explanation] = "The correct answer is #{question[:correct]}, which provides the most accurate information about this topic."
          end
        end
        
        # Ensure we have exactly 4 options (A, B, C, D)
        if question[:options].size < 4
          # Generate dummy options for any missing ones
          ["A", "B", "C", "D"].each do |letter|
            unless question[:options].any? { |opt| opt[:letter] == letter }
              question[:options] << { letter: letter, text: "Option #{letter} (placeholder)" }
            end
          end
        end
        
        # Make sure the correct answer is at position A if it's not already
        correct_option = question[:options].find { |opt| opt[:letter] == question[:correct] }
        if correct_option && question[:correct] != "A"
          # Find the current A option
          a_option = question[:options].find { |opt| opt[:letter] == "A" }
          
          # Swap the texts
          if a_option
            a_text = a_option[:text]
            a_option[:text] = correct_option[:text]
            correct_option[:text] = a_text
          end
          
          # Update the correct answer to be A
          question[:correct] = "A"
        end
      end
      
      questions
    end

    # Generate dummy test questions for development
    def dummy_test_questions
      # Create test questions from all cards
      @flash_card_set.cards.map.with_index do |card, index|
        # The front of the card is the term
        term = card[:front]
        # The back of the card is the correct definition
        definition = card[:back]
        
        # Create a question based on the card front
        question = "What is the correct definition of '#{term}'?"
        
        # Generate plausible but incorrect answers based on the correct answer
        incorrect_answers = generate_plausible_incorrect_answers(term, definition, @flash_card_set.cards)
        
        # Create detailed explanation for why the correct answer is right
        explanation = "The correct definition of '#{term}' is '#{definition}'. This is the accurate description as shown in the flashcard. The other options contain elements that might seem plausible but are not correct in this context. Understanding this definition is essential for mastering this concept."
        
        # Combine into a test question with correct answer ALWAYS at position A
        {
          question: question,
          options: [
            { letter: "A", text: definition },
            { letter: "B", text: incorrect_answers[0] },
            { letter: "C", text: incorrect_answers[1] },
            { letter: "D", text: incorrect_answers[2] }
          ],
          correct: "A",
          explanation: explanation
        }
      end
    end
    
    # Generate plausible incorrect answers by mixing definitions or creating variations
    def generate_plausible_incorrect_answers(term, correct_definition, all_cards)
      # Create an array to store our incorrect answers
      incorrect_answers = []
      
      # Split the term and definition into words for analysis
      term_words = term.downcase.split(/\W+/).reject(&:empty?)
      definition_words = correct_definition.downcase.split(/\W+/).reject(&:empty?)
      
      # Get other definitions from the set to use as distractors
      other_cards = all_cards.reject { |c| c[:front].downcase == term.downcase }
      
      # 1. First incorrect answer: Use another definition from the set if available
      if other_cards.any?
        # Try to find a related card based on shared words in term or definition
        related_cards = other_cards.select do |card|
          other_term = card[:front].downcase.split(/\W+/).reject(&:empty?)
          other_def = card[:back].downcase.split(/\W+/).reject(&:empty?)
          
          # Check for word overlap to find a related but different concept
          (term_words & other_term).any? || (definition_words & other_def).any?
        end
        
        if related_cards.any?
          # Use a related card's definition (more challenging distractor)
          incorrect_answers << related_cards.sample[:back]
        else
          # Fall back to a random different definition
          incorrect_answers << other_cards.sample[:back]
        end
      else
        # If no other cards, create a domain-specific wrong answer based on the term
        domain_answer = case
          when term =~ /java|class|method|interface|package/i
            "#{term} is a tool for code compilation in programming languages but does not organize related classes."
          when term =~ /\b(cell|organ|tissue|biology|membrane|mitochondria)\b/i
            "#{term} is responsible for protein synthesis in cells, but does not involve energy production."
          when term =~ /\b(math|equation|formula|calculus|algebra)\b/i
            "#{term} is used to calculate geometric shapes but not for solving equations."
          when term =~ /\b(history|war|century|ancient|medieval|revolution)\b/i
            "#{term} refers to events from the 19th century, though this timeframe is incorrect."
          else
            "#{term} is related to a completely different field and involves processes unrelated to its actual definition."
        end
        incorrect_answers << domain_answer
      end
      
      # 2. Second incorrect answer: Create a variation with incorrect meaning
      # Identify key domain based on term or definition words
      domain_words = {
        tech: ['software', 'program', 'code', 'computer', 'data', 'function', 'class', 'interface', 'method', 'algorithm'],
        science: ['theory', 'experiment', 'research', 'scientist', 'laboratory', 'study', 'hypothesis', 'evidence'],
        biology: ['cell', 'organism', 'species', 'evolution', 'protein', 'gene', 'tissue', 'membrane', 'enzyme'],
        business: ['market', 'company', 'finance', 'product', 'service', 'customer', 'profit', 'revenue', 'business']
      }
      
      # Determine likely domain of the term
      domain = domain_words.keys.find do |key| 
        (term_words & domain_words[key]).any? || (definition_words & domain_words[key]).any?
      end || :general
      
      # Generate domain-specific incorrect answer
      domain_specific_wrong = case domain
      when :tech
        "#{term} is a deprecated feature that was removed from modern programming languages due to security vulnerabilities."
      when :science
        "#{term} is a disproven scientific theory that was initially proposed to explain natural phenomena but has since been rejected."
      when :biology
        "#{term} is a cellular component found only in plant cells that aids in photosynthesis, though this is incorrect."
      when :business
        "#{term} is a financial strategy used to minimize tax liability for corporations, although this misconstrues its actual meaning."
      else
        # Create a opposite meaning by negating key aspects
        negated_def = correct_definition.gsub(/\b(is|are|can|does|enables|allows|provides)\b/i) { |match| "is not" }
        if negated_def == correct_definition
          "#{term} is commonly mistaken as related to #{definition_words.last(3).join(' ')}, but this is factually incorrect."
        else
          negated_def
        end
      end
      
      incorrect_answers << domain_specific_wrong
      
      # 3. Create a partially correct but fundamentally flawed answer
      # Extract key phrases from the correct definition
      phrases = correct_definition.scan(/[^,.]+[,.]/).map(&:strip)
      if phrases.size > 1
        # Take a portion of the correct definition but add an incorrect statement
        partial_correct = phrases.first
        contradiction = case domain
        when :tech
          " However, it cannot be used in production environments and is only for testing purposes."
        when :science
          " However, this concept has been largely discredited by recent research findings."
        when :biology
          " However, this only occurs in abnormal cell growth and is not part of standard cellular function."
        when :business
          " However, this approach is now considered obsolete in modern business practice."
        else
          " However, this interpretation is fundamentally flawed due to conceptual misunderstanding."
        end
        incorrect_answers << "#{partial_correct}#{contradiction}"
      else
        # If we can't break into phrases, create a confused explanation
        incorrect_answers << "#{term} is often confused with #{other_cards.first[:front] rescue 'related concepts'}, leading to fundamental misunderstandings about its purpose and application."
      end
      
      # Ensure all incorrect answers are different from the correct one and from each other
      incorrect_answers.map! { |answer| answer == correct_definition ? "#{term} is a different concept entirely from what is described in the correct definition." : answer }
      incorrect_answers.uniq!
      
      # Fill any missing answers if we don't have 3 unique incorrect answers
      while incorrect_answers.size < 3
        filler_wrong = case incorrect_answers.size
        when 0
          "#{term} refers to an outdated concept that has been replaced in modern understanding."
        when 1
          "While #{term} sounds like it might relate to #{definition_words.sample(2).join(' ')}, it actually has no connection to these concepts."
        else
          "#{term} is frequently misunderstood in popular culture, leading to this common but incorrect interpretation."
        end
        incorrect_answers << filler_wrong
      end
      
      # Ensure each incorrect answer is substantial
      incorrect_answers.map! do |answer|
        if answer.length < 40 # If answer is too short
          "#{answer} This interpretation fails to account for the essential characteristics and functions of #{term} in its proper context."
        else
          answer
        end
      end
      
      incorrect_answers
    end
end
