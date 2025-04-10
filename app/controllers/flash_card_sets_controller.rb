class FlashCardSetsController < ApplicationController
  before_action :set_flash_card_set, only: %i[ show edit update destroy toggle_favorite ]

  # GET /flash_card_sets or /flash_card_sets.json
  def index
    @flash_card_sets = FlashCardSet.where(user_mail: current_user.email_address)
  end

  # GET /flash_card_sets/1 or /flash_card_sets/1.json
  def show
    authorize_user_access!
    
    # Log info for debugging
    Rails.logger.debug("Accessing FlashCardSet ##{@flash_card_set.id} in format: #{request.format}")
    
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
    # Extract prompt from params - could be in different formats
    @prompt = params[:prompt].presence || params.dig(:flash_card_set, :prompt).presence
    
    # Check for prompt from plain JSON
    if @prompt.nil? && request.content_type =~ /json/i
      body = request.body.read
      json_params = JSON.parse(body) rescue nil
      @prompt = json_params["prompt"] if json_params
    end
    
    if @prompt.blank?
      msg = "Prompt cannot be empty"
      respond_to do |format|
        format.html { redirect_to flash_card_sets_path, alert: msg }
        format.json { render json: { error: msg }, status: :unprocessable_entity }
      end
      return
    end
    
    # Log the request
    Rails.logger.info("Generating flash cards for prompt: #{@prompt[0..50]}...")
    
    # Create a service instance
    ai_service = OpenAiService.new
    
    # Generate CSV content - pass prompt directly as in chat_client.rb
    csv_content = ai_service.generate_flashcards(@prompt)
    
    if csv_content.present?
      Rails.logger.info("Successfully generated CSV content")
      
      # Validate that the CSV has both fronts and backs
      begin
        parsed_data = CSV.parse(csv_content, headers: true)
        
        # Log the raw CSV data for debugging
        Rails.logger.info("Raw CSV data sample: #{csv_content[0..200]}")
        
        # Check for any missing backs or placeholders
        empty_backs = parsed_data.select do |row| 
          back = row["back"] || row["Back"]
          back.blank? || back == "No definition provided" || back.start_with?("No definition provided for")
        end
        
        if empty_backs.any?
          Rails.logger.warn("Generated CSV has #{empty_backs.size} cards with empty or placeholder backs")
          
          # Fix the CSV
          fixed_content = "front,back\n"
          parsed_data.each do |row|
            front = (row["front"] || row["Front"])&.to_s&.strip
            back = (row["back"] || row["Back"])&.to_s&.strip
            
            # Add a meaningful placeholder for empty backs
            if back.blank? || back == "No definition provided" || back.start_with?("No definition provided for")
              # Create a more descriptive default back
              back = if front.present?
                "This term refers to #{front} and is an important concept in this subject area."
              else
                "This is an important term or concept to understand."
              end
            end
            
            # Escape any commas
            front = front.to_s.gsub(',', ' ')
            back = back.to_s.gsub(',', ' ')
            
            fixed_content += "#{front},#{back}\n" if front.present?
          end
          
          csv_content = fixed_content
          Rails.logger.info("Fixed CSV to include meaningful backs for all cards. Sample: #{csv_content[0..200]}")
        end
        
        card_count = parsed_data.count
      rescue => e
        Rails.logger.error("Error validating CSV: #{e.message}")
        # Use the content anyway and let the model handle it
        card_count = 0
      end
      
      # Create a new flash card set with the generated content
      @flash_card_set = FlashCardSet.new(
        name: "#{@prompt.truncate(30, omission: '...')}",
        user_mail: current_user.email_address,
        flashcards: csv_content
      )
      
      # Set the length 
      @flash_card_set.length = card_count > 0 ? card_count : 3 # Default if we couldn't parse
      
      if @flash_card_set.save
        Rails.logger.info("Successfully saved flash card set: #{@flash_card_set.id}")
        
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
      else
        Rails.logger.error("Failed to save flash card set: #{@flash_card_set.errors.full_messages.join(', ')}")
        
        respond_to do |format|
          format.html { 
            flash[:alert] = "Failed to save generated flash cards: #{@flash_card_set.errors.full_messages.join(', ')}"
            redirect_to flash_card_sets_path
          }
          format.json { 
            render json: { 
              error: "Failed to save generated flash cards", 
              details: @flash_card_set.errors.full_messages 
            }, status: :unprocessable_entity 
          }
        end
      end
    else
      Rails.logger.error("Failed to generate CSV content from AI service")
      
      respond_to do |format|
        format.html { 
          flash[:alert] = "Failed to generate flash cards. Please try again later."
          redirect_to flash_card_sets_path
        }
        format.json { 
          render json: { error: "Failed to generate flash cards. Please try again later." }, 
          status: :unprocessable_entity 
        }
      end
    end
  rescue => e
    Rails.logger.error("Exception in generate action: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    
    respond_to do |format|
      format.html { 
        flash[:alert] = "An unexpected error occurred. Please try again later."
        redirect_to flash_card_sets_path
      }
      format.json { 
        render json: { error: "An unexpected error occurred. Please try again later." }, 
        status: :internal_server_error 
      }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flash_card_set
      @flash_card_set = FlashCardSet.find(params[:id])
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
end
