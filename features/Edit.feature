Feature: Editing a set

Scenario: Creating a card
Given I am on the edit set page
When I click add card
And I fill in the front
And I fill in the back
And I click save changes
Then The card should be created

Scenario: Deleting a card
Given I am on the edit set page
When I click delete card
And I click confirm
And I click save changes
Then The card should be deleted

Scenatio: Deleting a set
Given I am on the edit set page
When I click delete set
And I click confirm
Then The set should be deleted