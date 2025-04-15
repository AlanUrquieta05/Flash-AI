namespace :db do
  desc "Force create critical tables directly using SQL if they don't exist"
  task force_create_tables: :environment do
    conn = ActiveRecord::Base.connection
    
    # Check if users table exists
    if !conn.table_exists?(:users)
      puts "Users table missing, creating it..."
      conn.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          email_address VARCHAR NOT NULL,
          password_digest VARCHAR NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
        CREATE UNIQUE INDEX IF NOT EXISTS index_users_on_email_address ON users (email_address);
      SQL
      puts "Users table created."
    else
      puts "Users table already exists."
    end
    
    # Check if sessions table exists
    if !conn.table_exists?(:sessions)
      puts "Sessions table missing, creating it..."
      conn.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS sessions (
          id SERIAL PRIMARY KEY,
          user_id INTEGER NOT NULL,
          ip_address VARCHAR,
          user_agent VARCHAR,
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
          CONSTRAINT fk_sessions_users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS index_sessions_on_user_id ON sessions (user_id);
      SQL
      puts "Sessions table created."
    else
      puts "Sessions table already exists."
    end
    
    # Check if flash_card_sets table exists
    if !conn.table_exists?(:flash_card_sets)
      puts "Flash card sets table missing, creating it..."
      conn.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS flash_card_sets (
          id SERIAL PRIMARY KEY,
          user_mail VARCHAR,
          name VARCHAR,
          flashcards TEXT,
          length INTEGER,
          favorite BOOLEAN,
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
      SQL
      puts "Flash card sets table created."
    else
      puts "Flash card sets table already exists."
    end
    
    puts "Database tables check complete."
  end
end 