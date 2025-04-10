json.extract! @flash_card_set, :id, :name, :flashcards, :length, :favorite
json.created_at @flash_card_set.created_at.iso8601
json.updated_at @flash_card_set.updated_at.iso8601
json.url flash_card_set_url(@flash_card_set, format: :json)
json.cards @flash_card_set.cards || []
