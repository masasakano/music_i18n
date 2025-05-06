# coding: utf-8
require "test_helper"

# This file is designed to be included in Controller-test files about *MergesController
#
# @example
#    require_relative "../concerns/base_merges_helper"
#    class Musics::MergesControllerTest < ActionDispatch::IntegrationTest
#      include ActiveSupport::TestCase::BaseMergesHelper
#
module ActiveSupport::TestCase::BaseMergesHelper
  
  # from, to are the ActiveRecord merged from and to, respectively.
  #
  # Their notes and memo_editors must be significant! (caller's responsibility)
  #
  # @example
  #    @other.update!(memo_editor: "MemoEditorArtistAi")
  #    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: @other.id}})
  #    assert_response :success
  #    _assert_edit_html_note_memo_editor(@artist, @other)  # defined in ActiveSupport::TestCase::BaseMergesHelper
  #
  def _assert_edit_html_note_memo_editor(from, to)
    from_to = _hs_from_to(from, to)

    attr_origs = from_to.map{ |from_or_to, ea_artist|
      [from_or_to, %w(note memo_editor).map{|ea_attr| [ea_attr, ea_artist.send(ea_attr).dup]}.to_h.with_indifferent_access]
    }.to_h.with_indifferent_access
    # => attr_origs[:from][:note] etc.
    assert (hs=attr_origs.map{|_, ev| ev.values}.flatten).all?(&:present?), 'sanity check (including fixtures) so note/memo_editor are all present, but... '+hs.inspect

    csses = %w(note memo_editor).map{|ek| [ek, "table tr#merge_edit_"+ek]}.to_h.with_indifferent_access

    assert_response :success
    %w(note memo_editor).each do |eatt|
      assert css_select(csses[eatt]).present?
      assert_equal attr_origs[:from][eatt], css_select(csses[eatt]+' td')[0].text.strip
      assert_equal attr_origs[:to][eatt], (s=css_select(csses[eatt]+' td'))[1].text.strip, _get_caller_info_message(prefix: true)+" Other's #{eatt.inspect} should exist in table, but..."+s.to_s
      assert_includes                       css_select(csses[eatt]+' td')[2].text.strip, attr_origs[:from][eatt]
      assert_includes                       css_select(csses[eatt]+' td')[2].text.strip, attr_origs[:to][eatt], _get_caller_info_message(prefix: true)+" Merged #{eatt.inspect} expected to include this, but..."
    end
  end

  private
    def _hs_from_to(from, to)
      {
        from: from,
        to:   to,
      }.with_indifferent_access
    end
    private :_hs_from_to


end

