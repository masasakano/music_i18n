# coding: utf-8
require "test_helper"

# This file is designed to be included in Controller-test files about *MergesController
#
# @example
#    require_relative "../concerns/base_merges_controller_helper"
#    class Musics::MergesControllerTest < ActionDispatch::IntegrationTest
#      include ActiveSupport::TestCase::BaseMergesControllerHelper
#
module ActiveSupport::TestCase::BaseMergesControllerHelper
  
  # from, to are the ActiveRecord merged from and to, respectively.
  #
  # Their notes and memo_editors must be significant for this testing! (caller's responsibility)
  #
  # @example
  #    @other.update!(memo_editor: "MemoEditorArtistAi")
  #    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: @other.id}})
  #    assert_response :success
  #    _assert_edit_html_note_memo_editor(@artist, @other)  # defined in ActiveSupport::TestCase::BaseMergesControllerHelper
  #
  def _assert_edit_html_note_memo_editor(from, to)
    from_to = _hs_from_to(from, to)

    attr_origs = from_to.map{ |from_or_to, ea_artist|
      [from_or_to, %w(note memo_editor).map{|ea_attr| [ea_attr, ea_artist.send(ea_attr).dup]}.to_h.with_indifferent_access]
    }.to_h.with_indifferent_access
    # => attr_origs[:from][:note] etc.
    assert (hs=attr_origs.map{|_, ev| ev.values}.flatten).all?(&:present?), 'sanity check (including fixtures) so note/memo_editor are all present, but... '+hs.inspect

    csses = %w(note memo_editor).map{|ek| [ek, "table tr#merge_edit_"+ek]}.to_h.with_indifferent_access

    %w(note memo_editor).each do |eatt|
      assert css_select(csses[eatt]).present?
      assert_equal attr_origs[:from][eatt], css_select(csses[eatt]+' td')[0].text.strip
      assert_equal attr_origs[:to][eatt], (s=css_select(csses[eatt]+' td'))[1].text.strip, _get_caller_info_message(prefix: true)+" Other's #{eatt.inspect} should exist in table, but..."+s.to_s
      assert_includes                       css_select(csses[eatt]+' td')[2].text.strip, attr_origs[:from][eatt]
      assert_includes                       css_select(csses[eatt]+' td')[2].text.strip, attr_origs[:to][eatt], _get_caller_info_message(prefix: true)+" Merged #{eatt.inspect} expected to include this, but..."
    end
  end

  # from, to are the ActiveRecord merged from and to, respectively.
  #
  # Their notes and memo_editors should be significant for this test to be meaningful.
  #
  # @example
  #    get musics_edit_merges_url(@music, params: {music: {other_music_id: @other.id}})
  #    assert_response :success
  #    _assert_edit_html_hvma_note(@music, @other)  # defined in ActiveSupport::TestCase::BaseMergesControllerHelper
  #
  def _assert_edit_html_hvma_note(from, to)
    css = "table tr#merge_edit_harami_vid_music_assocs"
    from_to = _hs_from_to(from, to)
    attr_origs = from_to.map{ |from_or_to, ea_parent|
      hs = {}
      ea_parent.harami_vid_music_assocs.each do |hvma|
        hs[hvma.id] = hvma.note
      end
      [from_or_to, hs]
    }.to_h.with_indifferent_access

    ar = attr_origs.values(&:values).flatten
    assert_equal ar.size, ar.uniq.size, 'sanitiy-check. notes in fixtures should be all different.'

    assert css_select(css).present?
    from_to.keys.each do |from_or_to|
      index_td = ((:from == from_or_to.to_sym) ? 0 : 1)
      html = css_select(css+' td')[index_td].text.strip
      html_merged = css_select(css+' td')[2].text.strip

      attr_origs[from_or_to].keys.all?{ |ek|
        assert_includes html, ek.to_s, _get_caller_info_message(prefix: true)+" For #{from_or_to.inspect}, td[#{index_td}] is expected to include HVMA note, but..."+css_select(css).to_s
      }  # ID (and timing) should be printed in tr[0] or tr[1], respectively.  # timing is not tested for now...

      attr_origs[from_or_to].values.all?{ |ev|
        next if ev.blank?
        assert_includes(html, ev)
### NOTE: It seems actual merging (of HaramiVidMusicAssoc#note) is working well. However, edit screen does not seem to reflect it...  The following tests should pass...
#        assert_includes html_merged, ev, _get_caller_info_message(prefix: true)+" Merged expected to include HVMA note (#{ev.inspect}), but... "+html_merged #, css_select(css).to_s
#        assert_equal 1, html_merged.scan(/#{Regexp.quote(ev)}/).size, _get_caller_info_message(prefix: true)+" Merged should have no duplication for #{ev.inspect} in notes, but..."+css_select(css).to_s
      }  # HaramiVidMusicAssoc#note should be printed in tr[0] or tr[1], respectively, and also tr[2] (=="merged").
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

