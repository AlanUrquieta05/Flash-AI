Given('I am on the login page') do
  visit '/login'
end

Given('I click Sign Up') do
  click_link 'Sign Up'
end

When('I fill in the email') do
  fill_in 'user[email_address]', with: 'test@example.com'
end

When('I fill in the password') do
  fill_in 'user[password]', with: 'password123'
  fill_in 'user[password_confirmation]', with: 'password123'
end

Then('I should be back on the login page') do
  click_button 'Sign up'
  expect(page).to have_current_path('/session/new')
end

Given('I have created a user') do
  @user = User.create!(
    email_address: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123'
  )
end

When('I fill in a known email') do
  step 'I have created a user'
  fill_in 'email_address', with: @user.email_address
end

When('I fill in the known password') do
  fill_in 'password', with: 'password123'
  click_button 'Sign in'
end

Then('I should be on the homepage') do
  expect(page).to have_current_path('/home')
end 