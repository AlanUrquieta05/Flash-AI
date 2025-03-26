json.extract! flash_card_set, :id, :user_mail, :name, :flashcards, :length, :favorite, :created_at, :updated_at
json.url flash_card_set_url(flash_card_set, format: :json)
