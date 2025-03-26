class FlashCardSetsController < ApplicationController
  before_action :set_flash_card_set, only: %i[ show edit update destroy toggle_favorite ]

  # GET /flash_card_sets or /flash_card_sets.json
  def index
    @flash_card_sets = FlashCardSet.where(user_mail: current_user.email_address)
  end

  # GET /flash_card_sets/1 or /flash_card_sets/1.json
  def show
    authorize_user_access!
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
    respond_to do |format|
      if @flash_card_set.update(flash_card_set_params)
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flash_card_set
      @flash_card_set = FlashCardSet.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def flash_card_set_params
      params.require(:flash_card_set).permit(:name, :flashcards, :length, :favorite)
    end

    def authorize_user_access!
      unless @flash_card_set.user_mail == current_user.email_address
        redirect_to flash_card_sets_path, alert: "You are not authorized to access this flash card set."
      end
    end
end
