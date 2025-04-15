namespace :db do
  desc "Manual setup for Render deployment"
  task manual_setup: :environment do
    # Create users table
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email_address VARCHAR NOT NULL,
        password_digest VARCHAR NOT NULL,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      );
      CREATE UNIQUE INDEX IF NOT EXISTS index_users_on_email_address ON users (email_address);
    SQL
    
    # Create sessions table
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS sessions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        ip_address VARCHAR,
        user_agent VARCHAR,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        CONSTRAINT fk_sessions_users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS index_sessions_on_user_id ON sessions (user_id);
    SQL
    
    # Create flash_card_sets table
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS flash_card_sets (
        id SERIAL PRIMARY KEY,
        user_mail VARCHAR,
        name VARCHAR,
        flashcards TEXT,
        length INTEGER,
        favorite BOOLEAN,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      );
    SQL
    
    puts "Manual table creation completed!"
  end
end 