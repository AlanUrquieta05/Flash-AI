# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Sample flash card set
sample_csv = <<~CSV
front,back
Mitochondria,Powerhouse of the cell
Photosynthesis,Process by which plants convert light energy into chemical energy
DNA,Molecule that carries genetic instructions
Cell membrane,Barrier that separates cell interior from exterior environment
Nucleus,Control center of the cell containing genetic material
CSV

# Create a sample flash card set for the first user
User.first&.tap do |user|
  if user && !FlashCardSet.exists?(name: "Biology Basics")
    puts "Creating sample flash card set for user: #{user.email_address}"
    
    FlashCardSet.create!(
      name: "Biology Basics",
      user_mail: user.email_address,
      flashcards: sample_csv,
      length: 5,
      favorite: true
    )
  end
end

puts "Seed completed successfully!"
