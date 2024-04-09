# == Schema Information
#
# Table name: genres
#
#  id                                        :bigint           not null, primary key
#  note                                      :text
#  weight(Smaller means higher in priority.) :float
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#
require 'test_helper'

class GenreTest < ActiveSupport::TestCase
  test "unknown" do
    assert Genre.unknown
    assert_operator 0, '<', Genre.unknown.id
    obj = Genre[/UnknownGen/i, 'en']
    assert_equal obj, Genre.unknown
    assert obj.unknown?
  end

  test "not_disagree? with unknown" do
    genre = Genre.unknown
    assert_raises(TypeError){ genre.not_disagree?(3) }
    assert     genre.not_disagree?(nil)
    assert_not genre.not_disagree?(nil, allow_nil: false)
    assert     genre.not_disagree?(genres(:genre_classic))
    assert     genre.not_disagree?(genres(:genre_classic), allow_nil: false) 
    assert     genre.not_disagree?(genre)
    assert     genre.not_disagree?(genre, allow_nil: false)
  end

  test "not_disagree? with a significant" do
    genre = genres(:genre_classic)
    assert_raises(TypeError){ genre.not_disagree?(3) }
    assert     genre.not_disagree?(nil)
    assert_not genre.not_disagree?(nil, allow_nil: false)
    assert_not genre.not_disagree?(genres(:genre_pop))
    assert_not genre.not_disagree?(genres(:genre_pop), allow_nil: false) 
    assert     genre.not_disagree?(Genre.unknown)
    assert     genre.not_disagree?(Genre.unknown, allow_nil: false), "Genre.unknown=#{Genre.unknown.inspect}"
  end
end
