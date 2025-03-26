require "application_system_test_case"

class FlashCardSetsTest < ApplicationSystemTestCase
  setup do
    @flash_card_set = flash_card_sets(:one)
  end

  test "visiting the index" do
    visit flash_card_sets_url
    assert_selector "h1", text: "Flash card sets"
  end

  test "should create flash card set" do
    visit flash_card_sets_url
    click_on "New flash card set"

    check "Favorite" if @flash_card_set.favorite
    fill_in "Flashcards", with: @flash_card_set.flashcards
    fill_in "Length", with: @flash_card_set.length
    fill_in "Name", with: @flash_card_set.name
    fill_in "User mail", with: @flash_card_set.user_mail
    click_on "Create Flash card set"

    assert_text "Flash card set was successfully created"
    click_on "Back"
  end

  test "should update Flash card set" do
    visit flash_card_set_url(@flash_card_set)
    click_on "Edit this flash card set", match: :first

    check "Favorite" if @flash_card_set.favorite
    fill_in "Flashcards", with: @flash_card_set.flashcards
    fill_in "Length", with: @flash_card_set.length
    fill_in "Name", with: @flash_card_set.name
    fill_in "User mail", with: @flash_card_set.user_mail
    click_on "Update Flash card set"

    assert_text "Flash card set was successfully updated"
    click_on "Back"
  end

  test "should destroy Flash card set" do
    visit flash_card_set_url(@flash_card_set)
    click_on "Destroy this flash card set", match: :first

    assert_text "Flash card set was successfully destroyed"
  end
end
