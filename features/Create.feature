Feature: Creating set of cards

Scenario: Creating set of cards
Given I am on the create set page
When I fill in the front
And I fill in the back
And I name the set
And I click save changes
Then The set should be made