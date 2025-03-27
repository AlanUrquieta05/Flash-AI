Feature: Signing in/up

Scenario: Making a User
Given I am on the login page 
And I click Sign Up
When I fill in the email
And I fill in the password
Then I should be back on the login page

Scenario: Signing in
Given I am on the login page 
When I fill in a known email
And I fill in the known password
Then I should be on the homepage