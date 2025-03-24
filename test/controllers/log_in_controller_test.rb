require "test_helper"

class LogInControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get log_in_index_url
    assert_response :success
  end
end
