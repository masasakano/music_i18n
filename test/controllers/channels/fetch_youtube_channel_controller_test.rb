# coding: utf-8
require "test_helper"

# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : set this to ignore marshal but access Youtube-API
class Channels::FetchYoutubeChannelControllerTest < ActionDispatch::IntegrationTest
  include ModuleYoutubeApiAux  # for unit testing

  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @channel = channels(:channel_haramichan_youtube_main)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @harami_uris = {  # inferred from channels(:channel_haramichan_youtube_main)
      id_at_platform: "https://www.youtube.com/channel/UCr4fZBNv69P-09f98l7CshA",
      id_human_at_platform: "https://www.youtube.com/@haramipiano_main",
    }.with_indifferent_access

    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "use_cache_test" => true,
      "uri_youtube" => "", # id_at_platform or id_human_at_platform or URI or Video-URI
      "id_at_platform"       => "", # hidden: <= from id_at_platform
      "id_human_at_platform" => "", # hidden: <= from id_human_at_platform
    }.with_indifferent_access

    @def_create_params = @def_update_params.merge({
    }.with_indifferent_access)
    @h1129 = harami1129s(:harami1129_zenzenzense1)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should update" do
    # See /test/models/harami1129_test.rb
    @h1129.insert_populate

    assert @h1129.ins_song.present?
    hvid = @h1129.harami_vid
    assert hvid
    assert_equal @channel, hvid.channel

    @channel.update!(note: "Test-note" + (@channel.note || ""))
    note_be4 = @channel.note

    # sanity checks
    assert hvid.musics.first
    assert hvid.artists.first
    assert hvid.event_items.first
    assert hvid.uri.present?
    hvid.reload
    assert_equal 2, @channel.translations.size, 'sanity check'
    tra_be4 = @channel.translations.first
    assert_equal "ja", tra_be4.langcode

    channel_platform_be4 = @channel.channel_platform
    assert_equal "youtube", channel_platform_be4.mname

    id1_id     = @channel.id_at_platform
    id2_handle = @channel.id_human_at_platform

    yid = @h1129.link_root

    ## WARNING: This accesses Google Youtube API.  For this reason, these are commented out.  Uncomment them to run them.
    #set_youtube  # sets @youtube; defined in ModuleYoutubeApiAux
    #assert_nil get_yt_video("naiyo")
    ##

    ### preparation

    # This yields no change.
    hsin = {}.merge(@def_update_params.merge).merge({
      "id_at_platform" => @channel.id_at_platform,
      "id_human_at_platform" => @channel.id_human_at_platform,
    }).with_indifferent_access  # "use_cache_test" => true

    ## sign_in mandatory
    patch channels_fetch_youtube_channel_path(@channel), params: { channel: { fetch_youtube_channel: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    patch channels_fetch_youtube_channel_path(@channel), params: { channel: { fetch_youtube_channel: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified USUALLY. However, @channel (Harami) is special...
    # Same Japanese Translation, but English Translation is added.
    #sign_in @editor_harami
    #sign_in @moderator_all
    sign_in(user=@syshelper)

    ## No change in the 1st run, except the EN Translation.
    # preparation
    @channel.best_translations["en"].destroy!
    @channel.reload
    assert_empty @channel.translations.where(langcode: 'en'), "sanity check... Size=#{@channel.translations.where(langcode: 'en').size}"
    assert_equal 1, @channel.translations.size, 'sanity check'

    assert_no_difference("ChannelOwner.count + ChannelPlatform.count + ChannelType.count") do
      assert_difference("Translation.count*10 + Channel.count", 10) do  # English Translation added.
        patch channels_fetch_youtube_channel_path(@channel), params: { channel: { fetch_youtube_channel: hsin } }
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        assert_redirected_to @channel
      end
    end

    @channel.reload
    assert_equal note_be4, @channel.note, 'sanity check'
    assert_equal channel_platform_be4, @channel.channel_platform
    assert_equal id1_id,     @channel.id_at_platform, 'should change nothing, but...'
    assert_equal id2_handle, @channel.id_human_at_platform, 'should change nothing, but...'

    tras = @channel.translations
    assert_equal %w(en ja), tras.pluck(:langcode).flatten.sort
    refute_equal(*tras.pluck(:title))

    tra_en = tras.find_by(langcode: "en")
    assert_equal user, tra_en.create_user, "translations=#{tras.where(langcode: 'en').order(:weight).inspect}"

    ## 2nd and 3rd runs
    ## (id_at_platform and id_human_at_platform are missing, alternatively) 
    %w(id_at_platform id_human_at_platform).each do |att|
      @channel.update!({att => nil})
      assert_nil @channel.send(att), 'sanity check'

      hsin = {}.merge(@def_update_params.merge).merge({
        "id_at_platform" => @channel.id_at_platform,
        "id_human_at_platform" => @channel.id_human_at_platform,
      }).with_indifferent_access  # "use_cache_test" => true
      assert_no_difference("ChannelOwner.count + ChannelPlatform.count + ChannelType.count + Translation.count*10 + Channel.count") do
        patch channels_fetch_youtube_channel_path(@channel), params: { channel: { fetch_youtube_channel: hsin } }
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        assert_redirected_to @channel
      end

      @channel.reload
      assert                   @channel.id_at_platform,       'should be reimported, but...'
      assert                   @channel.id_human_at_platform, 'should be reimported, but...'
      assert_equal id1_id,     @channel.id_at_platform,       'should be reimported, but...'
      assert_equal id2_handle, @channel.id_human_at_platform, 'should be reimported, but...'
      assert_equal note_be4, @channel.note, 'sanity check'
    end

    ## 4-7th runs (4 different URI-ish parameters)
    # Both are missing.
    # This time, only Youtube-ID of Channel should be updated after it is deliberately unset.
    %w(id_at_platform id_human_at_platform).each do |att|
      @channel.update!(att => nil)
      assert_nil @channel.send(att)
    end
    prev_updated_time = @channel.updated_at
  
    uri_vid_long = sprintf "https://www.youtube.com/?v=%s&si=avbaxvva", hvid.uri.split("/")[-1]
    (@harami_uris.values+[@harami_uris[:id_human_at_platform].split("/")[-1], uri_vid_long]).each do |eprm|
      # ==["https://www.youtube.com/channel/...", "https://.../@haramipiano_main", "@haramipiano_main", uri_vid_long(see-above)]
      hsin = {}.merge(@def_update_params.merge).merge({
        "uri_youtube" => eprm,
        "id_at_platform" => "",
        "id_human_at_platform" => "",
      }).with_indifferent_access  # "use_cache_test" => true

      assert_no_difference("ChannelOwner.count + ChannelPlatform.count + ChannelType.count + Translation.count*10 + Channel.count") do
        patch channels_fetch_youtube_channel_path(@channel), params: { channel: { fetch_youtube_channel: hsin } }
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        assert_redirected_to @channel
      end

      @channel.reload
      #assert_operator prev_updated_time, :<, @channel.updated_at
      prev_updated_time = @channel.updated_at

      assert                   @channel.id_at_platform,       "eprm=#{eprm.inspect} channel=#{@channel.inspect}"
      assert                   @channel.id_human_at_platform, 'should be reimported, but...'
      assert_equal id1_id,     @channel.id_at_platform,       'should be reimported, but...'
      assert_equal id2_handle, @channel.id_human_at_platform, 'should be reimported, but...'
      assert_equal note_be4, @channel.note, 'sanity check'
    end
    sign_out @editor_harami
  end

  test "should update weights" do
    ######## Here by Editor-Harami
    sign_in (user=@editor_harami)

    ## 8th run (DESTRUCTIVE!!) (checking Translation update, esp. weight)
    def_weight = 100
    assert_equal def_weight, Role::DEF_WEIGHT[Role::RNAME_MODERATOR], "sanity check; see role.rb for definition"

    @channel.update!(create_user: @editor_ja)
    [[Float::INFINITY, def_weight], [98, 49], [0, 0]].each do |w_be4, w_aft|
      tra_ja_best = _destroy_all_trans_but_best_ja(@channel)
      tra_ja_best.update!(title: "naiyo-8th-run", weight: w_be4, update_user: @editor_ja, create_user: @editor_ja)  # Because it is by a different user, after accessing Youtube API, a new Translation should be created, except for the last trial, where Translation#weight is 0.

      hsin = {}.merge({"use_cache_test" => true})
      assert_difference("ChannelOwner.count + ChannelPlatform.count + ChannelType.count + Translation.count*10 + Channel.count", ((0 == w_be4) ? 10 : 20)) do
        # new JA and EN Translations created.
        patch channels_fetch_youtube_channel_path(@channel), params: { channel: { fetch_youtube_channel: hsin } }
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        assert_redirected_to @channel
      end

      tra = @channel.best_translation(langcode: :ja, fallback: false)
      assert_equal tra, @channel.translations.where(langcode: :ja).order(updated_at: :desc).first, "sanity check"
      assert_equal w_aft, tra.weight
    end

    sign_out (user=@editor_harami)
  end

  private

    # destroy all JA translations but the best one.  Also, completely destroys all EN translations.
    #
    # @return [Tranlstion] best one
    def _destroy_all_trans_but_best_ja(channel)
      tra_ja_best = channel.best_translation(langcode: :ja, fallback: false)
      channel.translations.where(langcode: :ja).where.not(id: tra_ja_best.id).destroy_all
      assert_equal 1, channel.translations.where(langcode: :ja).count, "sanity check so tra_ja_best with the new weight is the only JA translation."
      assert Translation.exists?(tra_ja_best.id)

      channel.translations.where(langcode: :en).destroy_all
      tra_ja_best
    end
end
