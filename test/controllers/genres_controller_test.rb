require 'test_helper'

class GenresControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @genre = genres(:genre_pop)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get genres_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  #test "should get new" do
  #  get new_genre_url
  #  assert_response :success
  #end

  #test "should create genre" do
  #  assert_difference('Genre.count') do
  #    post genres_url, params: { genre: { note: @genre.note } }
  #  end

  #  assert_redirected_to genre_url(Genre.last)
  #end

  #test "should show genre" do
  #  get genre_url(@genre)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_genre_url(@genre)
  #  assert_response :success
  #end

  #test "should update genre" do
  #  patch genre_url(@genre), params: { genre: { note: @genre.note } }
  #  assert_redirected_to genre_url(@genre)
  #end

  #test "should destroy genre" do
  #  assert_difference('Genre.count', -1) do
  #    delete genre_url(@genre)
  #  end

  #  assert_redirected_to genres_url
  #end
end
