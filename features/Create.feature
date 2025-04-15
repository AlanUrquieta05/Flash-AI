Feature: Creating set of cards

Scenario: Creating set of cards
Given I am logged in
And I am on the create set page
When I fill in the front and back
And I name the set
And I click Create Deck
Then The set should be made