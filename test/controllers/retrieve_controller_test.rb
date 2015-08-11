require 'test_helper'

class RetrieveControllerTest < ActionController::TestCase
  test "should get page" do
    get :page
    assert_response :success
  end

  test "should get news" do
    get :news
    assert_response :success
  end

  test "should get comment" do
    get :comment
    assert_response :success
  end

  test "should get vote" do
    get :vote
    assert_response :success
  end

end
