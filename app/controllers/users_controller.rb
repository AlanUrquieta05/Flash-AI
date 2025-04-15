class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    begin
      @user = User.new
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      Rails.logger.error("Database error in UsersController#new: #{e.message}")
      
      @error_message = "Database connection issue. Please try again later or contact support."
      render :error, status: :service_unavailable
    end
  end

  def create
    begin
      @user = User.new(user_params)
      
      if @user.save
        redirect_to new_session_path, notice: "Please check your email to confirm your account."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      Rails.logger.error("Database error in UsersController#create: #{e.message}")
      
      @error_message = "Database connection issue. Please try again later or contact support."
      render :error, status: :service_unavailable
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end 