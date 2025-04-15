class CreateMissingTables < ActiveRecord::Migration[8.0]
  def up
    # Check if users table exists and create it if not
    unless table_exists?(:users)
      create_table :users do |t|
        t.string :email_address, null: false
        t.string :password_digest, null: false
        t.timestamps
      end
      add_index :users, :email_address, unique: true
    end

    # Check if sessions table exists and create it if not
    unless table_exists?(:sessions)
      create_table :sessions do |t|
        t.references :user, null: false, foreign_key: true
        t.string :ip_address
        t.string :user_agent
        t.timestamps
      end
    end

    # Check if flash_card_sets table exists and create it if not
    unless table_exists?(:flash_card_sets)
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

  def down
    # This is a safety migration, so we don't want to drop tables
    # if we rollback
  end
end 