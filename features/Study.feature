Feature: Studying a set

Scenario: Studying a set
Given I am logged in
When I am on the homepage
And I have a flashcard set created
When I click study on the set
Then I should be on the study set page