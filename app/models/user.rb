class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  
  # Add authenticate_by class method for SessionsController
  def self.authenticate_by(attributes)
    # Find user with matching email, then authenticate with the provided password
    find_by(email_address: attributes[:email_address])&.authenticate(attributes[:password])
  end
end
