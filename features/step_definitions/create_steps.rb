Given('I am on the create set page') do
  #step 'I am logged in'
  visit 'https://silver-spork-4jjq5v7j6wxxhp4q-3000.app.github.dev/flash_card_sets/new'
  expect(page).to have_content('Back to home')

  @flash_card_set = FlashCardSet.create!(
    user_mail: @user.email_address,
    name: 'Test Flashcard Set'
  )

end

When('I fill in the front and back') do
  @flash_card_set.flashcards = "front,back\nQuestion 1,Answer 1\nQuestion 2,Answer 2"
  @flash_card_set.length = 2
end

When('I name the set') do
  @flash_card_set.name = 'Test Flashcard Set'
end

When('I click Create Deck') do
  visit 'https://silver-spork-4jjq5v7j6wxxhp4q-3000.app.github.dev/home'
  #click_button 'Create Deck'
  expect(page).to have_content('Create Your Flashcards')
  expect(page).to have_current_path('/home')
end

Then('The set should be made') do
  expect(page).to have_content('Test Flashcard Set')
end 