require "test_helper"

class FlashCardSetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @flash_card_set = flash_card_sets(:one)
  end

  test "should get index" do
    get flash_card_sets_url
    assert_response :success
  end

  test "should get new" do
    get new_flash_card_set_url
    assert_response :success
  end

  test "should create flash_card_set" do
    assert_difference("FlashCardSet.count") do
      post flash_card_sets_url, params: { flash_card_set: { favorite: @flash_card_set.favorite, flashcards: @flash_card_set.flashcards, length: @flash_card_set.length, name: @flash_card_set.name, user_mail: @flash_card_set.user_mail } }
    end

    assert_redirected_to flash_card_set_url(FlashCardSet.last)
  end

  test "should show flash_card_set" do
    get flash_card_set_url(@flash_card_set)
    assert_response :success
  end

  test "should get edit" do
    get edit_flash_card_set_url(@flash_card_set)
    assert_response :success
  end

  test "should update flash_card_set" do
    patch flash_card_set_url(@flash_card_set), params: { flash_card_set: { favorite: @flash_card_set.favorite, flashcards: @flash_card_set.flashcards, length: @flash_card_set.length, name: @flash_card_set.name, user_mail: @flash_card_set.user_mail } }
    assert_redirected_to flash_card_set_url(@flash_card_set)
  end

  test "should destroy flash_card_set" do
    assert_difference("FlashCardSet.count", -1) do
      delete flash_card_set_url(@flash_card_set)
    end

    assert_redirected_to flash_card_sets_url
  end
end
