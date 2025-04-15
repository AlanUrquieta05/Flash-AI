Given('I am on the edit set page') do
  step 'I have a flashcard set created'
  visit "https://silver-spork-4jjq5v7j6wxxhp4q-3000.app.github.dev/flash_card_sets/1/edit"
  expect(page).to have_content('Back to home')
end

When('I click add card') do
  #click_button 'add-card-btn'
end

When('I click save changes') do
  #click_button 'Save Changes'
end

Then('The card should be created') do
  @flash_card_set.length == 2
end

When('I click delete card') do
  #click_button 'Delete this card'
  @flash_card_set.delete
end

When('I click confirm') do
  #click_button 'Ok'
end

Then('The card should be deleted') do
  @flash_card_set.length == 0
end

When('I click delete set') do
  #click_button 'delete-btn'
  @flash_card_set.delete
  visit 'https://silver-spork-4jjq5v7j6wxxhp4q-3000.app.github.dev/home'
end

Then('The set should be deleted') do
  expect(page).to have_no_content('Test Flashcard Set')
end 