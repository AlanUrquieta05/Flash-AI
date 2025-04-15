Feature: Editing a set

Scenario: Creating a card
Given I am logged in
And I am on the edit set page
When I click add card
And I fill in the front and back
And I click save changes
Then The card should be created

Scenario: Deleting a card
Given I am logged in
And I am on the edit set page
When I click delete card
And I click confirm
And I click save changes
Then The card should be deleted

Scenario: Deleting a set
Given I am logged in
And I am on the edit set page
When I click delete set
Then The set should be deleted