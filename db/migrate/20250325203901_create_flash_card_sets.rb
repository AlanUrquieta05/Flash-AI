class CreateFlashCardSets < ActiveRecord::Migration[8.0]
  def change
    create_table :flash_card_sets do |t|
      t.string :user_mail
      t.string :name
      t.text :flashcards
      t.integer :length
      t.boolean :favorite

      t.timestamps
    end
  end
end
