# coding: utf-8
# == Schema Information
#
# Table name: harami_vids
#
#  id                                                  :bigint           not null, primary key
#  duration(Total duration in seconds)                 :float
#  memo_editor(Internal-use memo for Editors)          :text
#  note                                                :text
#  release_date(Published date of the video)           :date
#  uri((YouTube) URI of the video)                     :text
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#  channel_id                                          :bigint
#  place_id(The main place where the video was set in) :bigint
#
# Indexes
#
#  index_harami_vids_on_channel_id    (channel_id)
#  index_harami_vids_on_place_id      (place_id)
#  index_harami_vids_on_release_date  (release_date)
#  index_harami_vids_on_uri           (uri) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (channel_id => channels.id)
#  fk_rails_...  (place_id => places.id)
#
class HaramiVid < BaseWithTranslation
  include Rails.application.routes.url_helpers
  include ApplicationHelper # for link_to_youtube
  include ModuleCommon # for convert_str_to_number_nil, set_singleton_method_val etc

  # polymorphic many-to-many with Url
  include Anchorable

  before_validation :add_def_channel
  before_validation :normalize_uri

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = %i(uri)

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = false  # because title is a sentence.

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  TRANSLATION_UNIQUE_SCOPES = %i(uri)

  # If the place column is nil, insert {Place.unknown}
  # where the callback is defined in the parent class.
  # Note there is no DB restriction, but the Rails valiation prohibits nil.
  # Therefore this method has to be called before each validation.
  before_validation :add_default_place

#################################
#  after_create :save_unsaved_associates  # callback to create(-only) @unsaved_channel,  @unsaved_artist, @unsaved_music

  belongs_to :place     # see: before_validation and "validates :place, presence: true"
  belongs_to :channel   # see: before_validation :add_def_channel
  has_many :harami_vid_music_assocs, dependent: :destroy
  has_many :harami_vid_event_item_assocs,  dependent: :destroy
  has_many :musics, -> { order(Arel.sql('CASE WHEN harami_vid_music_assocs.timing IS NULL THEN 1 ELSE 0 END, harami_vid_music_assocs.timing')) }, through: :harami_vid_music_assocs   # in the order of timing in HaramiVidMusicAssoc, which is already joined. / n.b., because of this, "distinct" may raise an Exception.

  has_many :event_items, through: :harami_vid_event_item_assocs  # if the unique constraint is on for Association, `distinct` is not necessary for two-component associations (but it is for multi-components)
  has_many :events,       through: :event_items
  has_many :event_groups, through: :events
  has_many :artist_music_plays, through: :event_items, source: :artist_music_plays  # to an Association model! (NOT to Artists/Musics)
  has_many :artist_collabs, -> {distinct}, through: :event_items, source: :artists
  has_many :music_plays, -> {distinct}, through: :event_items, source: :musics

  has_many :artists,     through: :musics  # duplication is possible. "distinct" would not work with ordering! So, use uniq if required.
  has_many :harami1129s, dependent: :restrict_with_exception  # This used to be :nullify
  delegate :country,    to: :place, allow_nil: true
  delegate :prefecture, to: :place, allow_nil: true
  delegate :channel_owner,    to: :channel, allow_nil: true
  delegate :channel_type,     to: :channel, allow_nil: true
  delegate :channel_platform, to: :channel, allow_nil: true

  validates_uniqueness_of :uri, allow_nil: true  # allow_blank: false (??)
  validates :uri,   presence: true
  validates :place, presence: true  # NOT DB constraint, but Rails before_validation sets this with a default unknown Place.
  #validates :channel, presence: true  # before_validation  is taking care of. NOT DB constraint, but belongs_to constrains.
  validates_numericality_of :duration,     allow_blank: true, greater_than_or_equal_to: 0, message: "(%{value}) must be positive or 0."
  validates_numericality_of :music_timing, allow_blank: true, greater_than_or_equal_to: 0, message: "(%{value}) must be positive or 0."
  validates_numericality_of :music_year,       allow_blank: true, greater_than: 0, message: "(%{value}) must be positive."
  validates_numericality_of :form_engage_year, allow_blank: true, greater_than: 0, message: "(%{value}) must be positive."
  validates_numericality_of :form_engage_contribution, allow_blank: true, greater_than: 0, message: "(%{value}) must be positive."

  attr_accessor :unsaved_channel
  attr_accessor :unsaved_artist
  attr_accessor :unsaved_music
  attr_accessor :unsaved_event_item

  attr_accessor :form_new_event
  attr_accessor :form_channel_owner
  attr_accessor :form_channel_type
  attr_accessor :form_channel_platform
  attr_accessor :artist_name
  attr_accessor :artist_sex
  attr_accessor :form_engage_hows
  attr_accessor :form_engage_year
  attr_accessor :form_engage_contribution
  attr_accessor :artist_name_collab
  attr_accessor :form_instrument
  attr_accessor :form_play_role
  attr_accessor :music_collab  # Music for newly-added collaboration (select from Haramivid#musics)
  attr_accessor :music_name
  attr_accessor :music_timing  # n.b., there is a method "timing"
  attr_accessor :music_genre
  attr_accessor :music_year
  attr_accessor :form_new_artist_collab_event_item
  attr_accessor :reference_harami_vid_id   # String/Integer of pID of the HaramiVid to import (aka reference) its EventItem-s, used (optionally) in "new" and "edit" in Controller
  attr_accessor :reference_harami_vid_kwd  # This is a String of either pID or URI (with or without a scheme part), used only in "edit" in Controller.  If this is an Integer(-like String), it is the pID of HaramiVid to edit to which the page should be redirected with a query parameter of reference_harami_vid_id of the current HaramiVid pID.  If this is a URI-like String, (1) if there is a HaramiVid with the URI in the DB, the page should be redirected to its HaramiVid#edit (with a query parameter of reference_harami_vid_id of the current HaramiVid pID), and (2) else, the page should be redirected to HaramiVid#new with two query parameters of reference_harami_vid_id of the current HaramiVid pID and "uri" of this reference_harami_vid_kwd .
  # Example 1:  harami_vids/123/edit?reference_harami_vid_kwd=456          # => redirected to harami_vids/456/edit?reference_harami_vid_id=123
  # Example 2:  harami_vids/123/edit?reference_harami_vid_kwd=example.com/XYZ  # => redirected to harami_vids/new/?reference_harami_vid_id=123&uri=example.com/XYZ
  attr_accessor :missing_music_ids

  attr_accessor :form_info  # various information about the result of form inputs, especially in create.

  require "translation"  # Without these, tests sometimes fail...
  require "translatable.rb"
  require "place"
  DEF_PLACE = (
    (Place.unknown(country: Country['JPN']) rescue nil) ||
    Place.unknown ||
    Place.first ||
    if Rails.env == 'test'
#if defined?("places") && respond_to?(:places)  # In a very odd occasions, this would be needed, though this insertion would fail a HaramiVid Controller test.  Note that if you use this, /db/seeds/users.rb may fail with "Users.load_seeds is not defined."  Then, comment out these again, and run the test again, and it should work.
##if true
      begin
        places(:unknown_place_unknown_prefecture_japan) || nil  # In the test environment, a constant should not be assigned to a model.
      rescue NoMethodError
        warn "For some unknown (maybe cache-related) reason, this sometimes fails in testing.  If it happens, have a look at this point /app/models/harami_vid.rb and temporarily uncomment the if-clause, run tests, and comment-out again the if-clause before proceeding."
        raise
      end
#else
#  nil
#end
    else
      raise('No Place is defined, hence HaramiVid fails to be created/updated.: '+Place.all.inspect)
    end
  )

  # Hash with keys of Symbols of the columns to each String
  # value like 'youtu.be/yfasl23v'
  # The keys are [:be4, :aft][:ins_title, :ins_release_date, :ins_link_root, :ins_link_time, :event_item]
  #
  # Basically, [:be4] means the status of HaramiVid (NOT Harami1129) of the corresponding key
  # to Harami1129 before the execution.
  # For :event_item, the value is +HaramiVid.event_items.ids+ (Array!)
  attr_accessor :columns_for_harami1129

  # Returns true if at least one of {HaramiVid#uri} contains a "http" scheme prefix.
  #
  # According to the DB standard, they all should have the scheme prefix.
  # But this library does not, at the time of writing (v.1.21.1), which may change in the future.
  #
  # The actual values in the DB are regulated by the before-validation callback {normalize_uri},
  # which calls {HaramiVid.normalized_uri}, in which with_scheme is the key value.
  #
  # @TODO:
  #   "http" may accidentally get in. It may be worth considering...
  def self.uri_in_db_with_scheme?
    !!HaramiVid.where("uri LIKE 'http://%' OR uri LIKE 'https://%'").first
  end

  # Find a HaramiVid that has the given URI
  #
  # @param uri [URI, String]
  # @param with_time: [Boolean] The default here is false, the opposite of the routine this calls.
  # @return [HaramiVid, NilClass]
  def self.find_by_uri(uri, with_time: false)
    uri_norm = normalized_uri(uri.to_s, with_time: with_time)  # This removes the scheme and "www."
    uri_wh_wo_schemes = [true, false].map{|i|
      ApplicationHelper.normalized_uri_youtube(uri_norm, with_scheme: i, with_time: with_time, with_host: true)
    }

    HaramiVid.where(uri: uri_wh_wo_schemes).first
  end

  # True if self.place is consistent with those of EventItem-s and Event-s
  #
  # == Algorithm
  #
  # 1. If strict==true,  HaramiVid#place must be the {Place.minimal_covering_place} of all EventItem-s,
  # 2. If strict==false, HaramiVid#place must encompass it,
  # 3. {Place.minimal_covering_place} of all Event-s must encompass {HaramiVid#place}.
  # 4. If self.place is nil, always returns false.
  # 5. If none of Place-s for the associated EventItem-s and Event-s are defined (or more likely, no EventItem-s are associated to self (HaramiVid)), while self.place is defined,
  #    1. false if strict==true
  #    2. true  if strict==false (permissive, ignoring the incomplete Place settings)
  #
  # For example, when HaramiVid is associated the following two EventItem-s,
  #
  # 1. Event1 (Tocho) > EventItem1_1 (Tocho)
  # 2. Event2 (Japan) > EventItem2_1 (Akihabara)
  #
  # If strict is true  {HaramiVid#place} must be "UnknownPlace of Tokyo" (condition 1, which also satisfies condition 3),
  # If strict is false, {HaramiVid#place} must be either "UnknownPlace of Tokyo" (condition 2 as minimum)
  # or "UnknownPlace of Japan" (condition 3 as the maximum).
  #
  # @note
  #   This method does not check the consistency of Place-s between Event and EventItem-s.
  #   If they are inconsistent, this may return false no matter what HaramiVid#place is.
  #
  # @param strict [Boolean[  see above.
  def is_place_all_consistent?(strict: true)
    return false if !place
    if event_items.pluck(:place_id).any?(&:nil?) || events.pluck(:place_id).any?(&:nil?)
      # in unlikely cases of EventItem#place or Event#place being nil (should never happen)
      return !strict
    end

    evit_plas, ev_plas =
      [event_items.left_joins(:place),
       event_items.joins(:event).joins("LEFT OUTER JOIN places ON events.place_id = places.id")
      ].map{|erel|
        erel.select("places.id as pla_id").map{|i| i[:pla_id]}.uniq.map{|j| Place.find j}
      }

    # No EventItems are associated.
    return !strict if evit_plas.empty? && ev_plas.empty?

    ### The following ignores those with NULL place. Though it should never happen, they should be handled for safety.
    # ev_plas   = Place.joins(:events).joins(events: :event_items).joins(events: {event_items: :harami_vid_event_item_assocs}).where("harami_vid_event_item_assocs.harami_vid_id = ?", id).distinct
    # evit_plas = Place.joins(:event_items).joins(event_items: :harami_vid_event_item_assocs).where("harami_vid_event_item_assocs.harami_vid_id = ?", id).distinct

    evit_cover_pla = Place.minimal_covering_place(*(evit_plas.uniq))
    ev_cover_pla   = Place.minimal_covering_place(*(ev_plas.uniq))

    ev_cover_pla.encompass?(place) &&
      (strict ? (place == evit_cover_pla) : place.encompass?(evit_cover_pla))
  end

  # Regulates how {HaramiVid#uri} is saved on the DB
  #
  # The scheme is excluded, unless it is an unusual scheme like "gopher://".
  # Except for the most popular few websites, the unsafe scheme "http://" may remain
  # in an unlikely case where a user attempts to input a URI with "http" as opposed to "https".
  # See {ApplicationHelper._normalized_uri_youtube_core} for detail.
  #
  # Also, the prefix "www." is removed, too.
  #
  # @return [String] returns the normalized URI as saved to the DB.  Time parameter remains as specified.
  def self.normalized_uri(uri,  with_time: true)
    ApplicationHelper.normalized_uri_youtube(uri, long: false, with_scheme: false, with_host: true,  with_time: with_time).sub(/\Awww\./, "")
  end

  # @return [String, NilClass] returns the normalized URI as saved to the DB.  Used in the callback {#normalize_uri}
  def normalized_uri(with_time: true)
    uri.present? ? self.class.send(__method__, uri, with_time: with_time) : nil
  end

  # Returns {HaramiVidMusicAssoc#timing} of a {Music} in {HaramiVid}, assuming there is only one timing
  #
  # @param music [Music]
  # @return [Integer, NilClass]
  def timing(music)
    assocs = harami_vid_music_assocs.where(music: music).order(Arel.sql('CASE WHEN timing IS NULL THEN 1 ELSE 0 END, timing'))
    case (n=assocs.count)
    when 0
      return nil
    when 1
      # OK
    else
      # Records it in the log file.
      msg = sprintf "HaramiVid(ID=%d) has multiple (%d) timings for Music (ID=%d).", self.id, n, music.id
      logger.warn msg
    end
    # Guaranteed to be the first one
    assocs.first.timing
  end

  # Returns an existing or new record (HaramiVid) that matches the given Harami1129 record
  #
  # If "uri" perfectly agrees, that is the definite identification.
  #
  # Else,
  # A new one is returned if {Harami1129#event_item} is nil or +recreate_harami_vid+ is true.
  # Or, nil is returned if {Harami1129#ins_link_root} is blank or
  # if +recreate_harami_vid+ is false (and {Harami1129#event_item} is non-nil).
  # In the latter case, {Harami1129#errors} is set.
  #
  # @param harami1129 [Harami1129]
  # @param recreate_harami_vid [Boolean] When {Harami1129#event_item} is nil, if this is true (Def: false),
  #    and if no existing HaramiVid with the URI is found, this still returns a new HaramiVid (usually nil is returned).
  # @return [HaramiVid, NilClass]
  def self.find_one_for_harami1129(harami1129, recreate_harami_vid: false)
    return nil if harami1129.ins_link_root.blank? #&& !harami1129.event_item  # if ins_link_root is nil, internal_insert has not been done, yet.

    uri = ApplicationHelper.uri_youtube(harami1129.ins_link_root)
    cand = self.find_by(uri: uri)
    return cand if cand

    #### Because HaramiVid#uri is unique, no multiple HaramiVids should ever match. Leaving the following just for record.
    # cands = self.where(uri: uri)
    # n_cands = cands.count
    # if n_cands > 0
    #   ret = cands.first
    #   if n_cands != 1
    #     msg = sprintf "multiple (n=%d) HaramiVids found (IDs=%s), corresponding to Harami1129(ID=%d) of uri= %s / Among them, HaramiVid (ID=%d) is now associated to Harami1129.", n_cands, cands.ids.inspcect, harami1129.id, uri, cands.first.id
    #     logger.warn msg
    #     ret.errors.add :base, msg
    #   end
    #   return ret
    # end

    return self.new if !harami1129.event_item || recreate_harami_vid

    # EventItem exists but HaramiVid does not!  HaramiVid must have been manually destroyed (whether intentionally or not).
    # In this case, nil is returned.
    # Message includes info about HaramiVid(s) that is associated with the EventItem
    cands = HaramiVid.joins(harami_vid_event_item_assocs: :event_item).joins(harami1129s: :event_item).where("harami1129s.id" => harami1129.id)
    msg = sprintf("This Harami1129 (URI= %s) has an associated EventItem (ID=%d) but no associated HaramiVid. FYI, ", uri, harami1129.event_item_id)
    msg << 
      if cands.exists?
        sprintf("multiple HaramiVids (IDs=%s) are found associated to the EventItem.", cands.ids.inspect)
      else
        "no HaramiVid is found associated to the EventItem."
      end
    msg << ' You may run "Populate (Recreate HaramiVid)"'

    logger.warn msg
    harami1129.errors.add :base, msg
    nil
  end

  # New HaramiVid where all associations are copied and new
  #
  # Harami1129 association is not copied.
  #
  # NOTE: uri must be set before save!
  #
  # @param uri: [String, NilClass] 
  # @param translation: [Translation, Symbol, NilClass] if :default, "(Copy)" is prefixed.
  def deepcopy(uri: nil, translation: nil, **trans_kwds)
    if !translation && trans_kwds.empty?
      raise ArgumentError, "Either translation or keyword parameters for Translation must be given."
    end

    # This should copy channel, place, note
    newmdl = dup
    newmdl.uri = uri  # nil in default

    if :default == translation
      trans = best_translation.dup
      trans.weight = Float::INFINITY

      ["", "alt_"].each do |prefix|
        revised_strs = _unique_copy_title(trans, prefix)  # its elements may be nil
        %w(title ruby romaji).each_with_index do |metho_root, i|
          metho = prefix + metho_root
          trans.send(metho+"=", revised_strs[i]) if revised_strs[i]
        end
      end
    elsif !translation
      trans = Translation.new(translation)
    end

    newmdl.unsaved_translations << trans

    harami_vid_music_assocs.order(:timing).each do |assoc|
      new_assoc = assoc.dup
      new_assoc.harami_vid = nil
      new_assoc.timing = nil
      newmdl.harami_vid_music_assocs << new_assoc
    end

    harami_vid_event_item_assocs.each do |assoc|
      new_assoc = assoc.dup
      new_assoc.harami_vid = nil
      newmdl.harami_vid_event_item_assocs << new_assoc
    end

    newmdl
  end

  # Returns a unique String (and its ruby and romaji) for a copied title.
  #
  # Note that the prefix for title can be "(Copy) ", "(Copy2) ", "(Copy3) ", "(Copy9) ", "(Copy10) ", etc, i.e., no "Copy1"
  # If self does not have a significant +title+ (or +ruby+ or +romaji+), the returned one for it is nil.
  # This means the return can be +[nil, nil, nil]+ (if, for example, self does not have alt_title and if method_prefix=="alt_").
  #
  # @param trans [Translation] reference Translation
  # @param method_prefix [String] "" (for title) or "alt_" (for alt_title)
  # @param num_ini: [Integer] Starting number for the copies
  # @return [Array<String, NilClass>] 3-element Array of a unique String of "(Copy23) My Original title" etc, and its ruby and romaji
  def _unique_copy_title(trans, method_prefix, num_ini: 1)
    metho = method_prefix+"title"
    return [nil, nil, nil] if (org_title=trans.send(metho)).blank?

    orig_strs = [org_title] + %w(ruby romaji).map{|metho_root|
      metho = method_prefix + metho_root
      (str=trans.send(metho)).present? ? str : nil
    }

    (num_ini..).each do |num|
      raise "Something has gone very wrong!" if num > 10001

      num_postfix = ((1==num) ? "" : sprintf("%d", num))

      new_strs = %w(Copy コピー kopii).map.with_index{ |new_prefix, i| 
        orig_strs[i] ? sprintf("(%s%s) %s", new_prefix, num_postfix, orig_strs[i]) : nil 
      }

      return new_strs if !Translation.find_by(translatable_type: self.class.name, method_prefix + "title" => new_strs[0])
    end
  end
  private :_unique_copy_title

  # Associates a Music to self consistently (in terms of HaramiVidMusicAssoc and ArtistMusicPlay through HaramiVidMusicAssoc )
  #
  # ArtistMusicPlay is required for {EventItem} to associate a Music; so it increases by 1 (unless already existent).
  # In contrast, a new (unless existent) HaramiVidMusicAssoc is required for each HaramiVid associated to the EventItem.
  # Therefore, this method produces 1 ArtistMusicPlay and the number of HaramiVid-s HaramiVidMusicAssoc.
  #
  # If self is new, this does save self or {HaramiVidMusicAssoc} BUT saves an {ArtistMusicPlay}!
  # You may enclose the calling routine with +transaction(requires_new: true)+
  # If self is not new, this immediately saves 2 records (HaramiVidMusicAssoc and ArtistMusicPlay).
  #
  # If there are other {HaramiVid}-s associated to +event_item+ they must be given along with
  # their timings in +others+, or alternatively others=:auto can be given; otherwise this raises
  # an Exception.
  #
  # @note The caller should do
  #    self.reload  # or
  #    self.harami_vid_music_assocs.reset
  #    self.artist_music_plays.reset
  #
  # @note for debugging purposes, try to run with (because it may raise an Exception): bang: true, update_if_exists: false
  #
  # @example 
  #   amp, hvmas = hvid.associate_music!(music0, evit0, timing: 6, others: :auto)
  #   amp, hvmas = hvid.associate_music!(music1, evit0, timing: 6, others: [other_hvid1, other_hvid2])
  #   amp, hvmas = hvid.associate_music!(music2, evit0, timing: 9, others: [[hvid1, 95, nil], [hvid2, nil, 1.0]])
  #     # n.b., hvmas[-1] is the created HaramiVidMusicAssoc for self (or the one that will be saved if new_record?).
  #
  # @param music [Music]
  # @param event_item [EventItem, NilClass] This can be nil **only if only one EventItem is associated**, which will be used. Otherwise, this raises an Exception.
  # @param others [Array<Array<HaramiVid, Numeric, Numeric>>, Symbol] Array of Array of the other {HaramiVid}-s associated to event_item and their timings and completeness (which can be nil), or simple Array of the former. Or, Symbol :auto is accepted, meaning the Music gets associated to the other HaramiVid-s with NULL timing.
  # @param timing: [Numeric, NilClass] for HaramiVidMusicAssoc
  # @param completeness: [Numeric, NilClass] for HaramiVidMusicAssoc
  # @param artist_play [Artist, NilClass]
  # @param play_role: [PlayRole, NilClass]
  # @param instrument: [Instrument, NilClass]
  # @param contribution_artist [Numeric, NilClass] for ArtistMusicPlay
  # @param cover_ratio [Numeric, NilClass] for ArtistMusicPlay
  # @param bang: [Boolean] if true (Def: false), uses create! or update! instead of +find_or_initialize_by+ (useful for testing)
  # @param update_if_exists: [Boolean] if true (Def), +update+ in an (unlikely) case of finding an existing record; else +create+ (or create! if bang)
  # @return [Array<ArtistMusicPlay, Array<HaramiVidMusicAssoc>>] newly associated records (or possibly already associated ones that satisfy all the given conditions, if bang is false (Default)).
  #   the former is always saved, but the latter is not in the case of new self.
  #   To get the actual HaramiVidMusicAssoc, you may need to actively find it for HaramiVid, referencing the returned one.
  #   At the time of writing, if not a new record and if bang is false, it is guaranteed to be a proper record.
  #   The orders of the Array of HaramiVidMusicAssoc follow the given others **appended** by that for self.
  def associate_music(music, event_item=nil, others: [], timing: nil, completeness: nil, bang: false, update_if_exists: true, **opt_args)
    raise ArgumentError, "ERROR(HaramiVid##{__method__}): Argument 'others' must be a double Array, but it does not appears so: others=#{others.inspect}" if others.present? && others[1].is_a?(Numeric)
    if !event_item
      if 1 == event_items.count
        event_item = event_items.first
      else
        raise ArgumentError, "ERROR(HaramiVid##{__method__}): No EventItem is specified or found (or ambiguous): event_item=#{event_item.inspect}"
      end
    elsif !event_items.find_by(id: event_item.id)  # sanity check!
      raise ArgumentError, "ERROR(#{File.basename __FILE__}:#{__method__}): Specified event_item is not associated to self (HaramiVid: ID=#{id}) - associate it before the call: event_item=#{event_item.inspect}"
    end

    event_item_hvids = event_item.harami_vids.where.not("harami_vids.id = ?", self.id)
    prm_music_vids = _get_harami_vids_timings((:auto == others) ? event_item_hvids.to_a : others)  # Hash[ HaramiVid => [timing, completeness] ]

    if (:auto != others)
      event_item_hvids.each do |ea_hvid|
        raise "ERROR(HaramiVid##{__method__}): Specified EventItem are associated with multiple HaramiVids, but at least one of them (ID=#{ea_hvid.id}) is not specified with the option others: #{others.inspect})" if !prm_music_vids.keys.include?(ea_hvid)
      end
    end
    prm_music_vids[self] = [timing, completeness]

    amp = nil
    hvmas = []
    ActiveRecord::Base.transaction(requires_new: true) do
      hvmas = _update_or_create_hvmas(music, prm_music_vids, bang: bang, update_if_exists: update_if_exists)
      amp   = _update_or_create_amp(  music, event_item,     bang: bang, update_if_exists: update_if_exists, **opt_args)
    end

    [amp, hvmas]
  end

  # @return [Hash<Array<HaramiVid> => Array[<Numeric, NilClass>]>] {HaramiVid => [timing, completeness]}
  def _get_harami_vids_timings(arin)
    [[], []] if arin.blank?
    arin.map{ |ea|
      ea.respond_to?(:last) ? [ea.first, [ea[1], ea[2]]] : [ea, [nil, nil]]
    }.to_h
  end
  private :_get_harami_vids_timings

  # Returns an Array of newly created and associated HaramiVidMusicAssoc (or possibly already associated ones that satisfy all the given conditions, if bang is false (Default).
  #
  # They may not be already saved if HaramiVid in prm_music_vids is new_record?
  # To get the actual HaramiVidMusicAssoc, you may need to actively find it for HaramiVid, referencing the returned one.
  # At the time of writing, if not a new record and if bang is false, they are guaranteed to be already saved.
  #
  # @param music [Music] 
  # @param prm_music_vids [Hash]  {HaramiVid => [timing, completeness]}  see #{_get_harami_vids_timings}
  # @param update_if_exists: [Boolean] if true (Def), +update+ in an (unlikely) case of finding an existing record; else +create+ (or create! if bang)
  # @return [Array<HaramiVidMusicAssoc>] newly created (or updated) ones
  def _update_or_create_hvmas(music, prm_music_vids, bang: false, update_if_exists: true)
    hvmas = []

    prm_music_vids.each_pair do |evid, opts|
      if update_if_exists && !evid.new_record?
        hvma = HaramiVidMusicAssoc.find_or_initialize_by(harami_vid: evid, music: music)
        hvma.timing       = opts[0] if opts[0] # timing not updated if nil is given
        hvma.completeness = opts[1] if opts[1] # completeness not updated if nil is given
        hvma.send(bang ? :save! : :save)
      else
        hvma = HaramiVidMusicAssoc.new(music: music, timing: opts[0], completeness: opts[1])
        if evid.new_record?
          evid.harami_vid_music_assocs << hvma
        else
          hvma.harami_vid = evid
          hvma.send(bang ? :save! : :save)
        end
      end
      hvmas.push hvma
      copy_errors_from(hvma)  # defined in application_record.rb
    end

    hvmas
  end
  private :_update_or_create_hvmas

  # Internal routine to create/update {ArtistMusicPlay}
  #
  # @param music [Music]
  # @param event_item [EventItem, NilClass] This can be nil **only if only one EventItem is associated**, which will be used. Otherwise, this raises an Exception.
  # @param artist_play [Artist, NilClass]
  # @param play_role: [PlayRole, NilClass]
  # @param instrument: [Instrument, NilClass]
  # @param contribution_artist [Numeric, NilClass] for ArtistMusicPlay
  # @param cover_ratio [Numeric, NilClass] for ArtistMusicPlay
  # @param bang: [Boolean] if true (Def: false), uses create! or update! instead of +find_or_initialize_by+ (useful for testing)
  # @param update_if_exists: [Boolean] if true (Def), +update+ in an (unlikely) case of finding an existing record; else +create+ (or create! if bang)
  # @return [Array<HaramiVidMusicAssoc>] newly created (or updated) ones
  def _update_or_create_amp(music, event_item=nil, artist_play: nil, play_role: nil, instrument: nil, contribution_artist: nil, cover_ratio: nil, bang: false, update_if_exists: true)
    artist_play ||= Artist.default(:HaramiVid)
    play_role   ||= PlayRole.default(:HaramiVid)
    instrument  ||= Instrument.default(:HaramiVid)

    mandatories = {event_item: event_item, artist: artist_play, music: music, play_role: play_role, instrument: instrument}.with_indifferent_access
    options = {contribution_artist: contribution_artist, cover_ratio: cover_ratio}.with_indifferent_access
    if update_if_exists
      amp = ArtistMusicPlay.find_or_initialize_by(mandatories)
      amp.contribution_artist = contribution_artist if contribution_artist # not updated if nil is given
      amp.cover_ratio         = cover_ratio         if cover_ratio         # not updated if nil is given
      metho = (bang ? :update! : :update)
      amp.send(metho, options)
    else
      amp = ArtistMusicPlay.new(mandatories.merge(options))
      metho = (bang ? :save! : :save)
      amp.send(metho)
    end

    copy_errors_from(amp)  # defined in  # application_record.rb
    amp
  end
  private :_update_or_create_amp

  # self.errors are set, copied from {ArtistMusicPlay#errors}, if anything has gone wrong.
  #
  # Usually, HaramiVid should have at least 1 {EventItem} — that is the constraint
  # for any newly created HaramiVid and those that is associated with an EventItem;
  # i.e., {HaramiVid#event_items} is not allowed to be empty.
  #
  # However, a legacy Hramivid may have no {EventItem} associated. HaramiVidsController
  # and Views force the user via UI to specify 1 new EventItem. So, such a legacy
  # HaramiVid should have at least 1 EventItem by the time they call this method.
  #
  # An exception is when a GET paraeter +ref_harami_vid+ (instance variable +@ref_harami_vid+
  # is given to HaramiVidsController on either create or update.  In such a case,
  # a HaramiVid is not unlikely to have multiple HaramiVids, but then, one (or more) of
  # the EventItem-s should be associated with Music and default Artist already.
  # If none of them is associated to a Music that HaramiVid is associated, then
  # there is an uncertainly problem of which EventItem should be used to associate
  # to the Music.
  #
  # In such a case, this method raises a (*html_safe*) warning, also adding a singleton method of
  # +HaramiVid#warning_messages+ (returning an Array), and skips the processing.
  # The caller (Controller?) may deal with the warning, transferring the Array to `flash[:warning]`
  # Note that this method *alyways* set the singleton method +HaramiVid#warning_messages+ to self,
  # which returns an empty Array [] in normal circumstances.
  #
  # The reason is this. If all of these EventItems are associted to some other HaramiVids 
  # and if none of the HaramiVids have the Music of interest, then
  # adding an association to Music and the EventItem would contradict
  # the fact the other HaramiVid(s) doss not have the Music(!).  Note that
  # a HaramiVid having a Music (via HaramiVidMusicAssoc) but not an ArtistMusicPlay
  # for the Music is fine because the latter means someone actually plays a Music
  # (in the HaramiVid) whereas the former simply means Music is somehow related to the HaramiVid;
  # however, the other way around is undesirable.
  #
  # So, a practical strategy is to specify +ref_harami_vid+ only when the existing
  # one is the superset of the current one, such as, the existing one being
  # the full video and the current one being a short like TikTok.
  # Also, it is best not specify a new Music when +ref_harami_vid+ is given
  # (maybe constrined via UI?).
  #
  # In practice, such a situation (of multiple candidates) may occur via UI when
  #
  # 1. a user specifies +ref_harami_vid+, referring to an existing HaramiVid none of
  #    the associated EventItems of which have Musics of the current HaramiVid because
  #    1. the existing HaramiVid is either a subset of the current HaramiVids
  #       (hence having fewer EventItems than those the current one should have),
  #       or simpley unrelated (either by mistake or by intention, such as, the user
  #       intends to amend the set of EventItems later).
  # 2. a user specifies a new Music, yet reusing old EventItem-s?
  #
  # @param music_except: [Music] ignores this (single) Music if specified.
  #    See {HaramiVidsController#create_artist_music_plays} for its use.
  # @param form_attr [Symbol] usually the form's name
  # @return [Arrray<ArtistMusicPlay>] If everything goes well, the same thing can be accessed by {#artist_music_plays}. However, if (one of) save fails, this Array (also) contains the ArtistMusicPlay for which saving failed.
  def associate_harami_existing_musics_plays(event_item=nil, instrument: nil, play_role: nil, music_except: nil, form_attr: :base)
    set_singleton_method_val(:warning_messages, [], clobber: false)  # defined in module_common.rb

    if event_item
      evit_ids = event_item.id  # Integer (but OK as far as +where+ clauses are concerned)
    else
      evit_ids = event_item_ids # Array of Integers
      if evit_ids.empty?
        raise "ERROR:(HaramiVid##{__method__}) No EventItem is specified or found."
      end
    end
    evit = (event_item || EventItem.find(evit_ids.first))  # NOTE: In the latter case, the first one is used in ArtistMusicPlay.initialize_default_artist() to initialize an ArtistMusicPlay in case no existing one is found for the given Array of IDs of EventItems.

    arret = []
    musics.each do |music|
      next if music_except == music
      arret << amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item: event_item, event_item_ids: evit_ids, music: music, instrument: instrument, play_role: play_role)  # new for the default ArtistMusicPlay (event_item and music are mandatory to specify.
      next if !amp.new_record?

      #### NOTE: If multiple EventItems are specified and ambiguous which one is used to create an ArtistMusicPlay, the first one is used now.
      #
      #if !event_item && evit_ids.size > 1
      #  msg = "Multiple EventItem-s are specified to associate to HaraiVid's Music (#{music.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true).inspect}). Playing association is not created. You may manually add it later."
      #  self.warning_messages << ERB::Util.html_escape("Warning: "+msg)  # alternative of flash[:warning]
      #  msg = "WARNING:(HaramiVid##{__method__}) "+msg
      #  warn msg
      #  logger.warning msg
      #  next
      #end

      next if amp.save  # may or may not succeed.

      # This should not fail, but just in case...
      amp.errors.full_messages.each do |msg|
        errors.add form_attr, ": Existing ArtistMusicPlay is not found, yet failed to create a new one for EventItem (pID=#{evit.id}: #{evit.machine_title.inspect}) and Music (pID=#{music.id}: #{music.title.inspect}): "+msg
      end
    end
    artist_music_plays.reset
    arret
  end

  # Sets the data from {Harami1129}
  #
  # self is modified but NOT saved, yet.
  #
  # Note this record HaramiVid is one record per video. Therefore,
  # {Harami1129#link_time} will not be referred to and will be recorded in HaramiVidMusicAssoc.
  #
  # The returned model instance may be filled with, if existing, all updated information
  # as specified in updates. If updates do not contain the column
  # (e.g., :ins_title), nothing is done. An existing column is not
  # updated in default (regardless of updates) unless force option is specified.
  #
  # As for {EventItem}, if HaramiVid has no child EventItem and if Harami1129 belongs to one,
  # HaramiVid's one is updated (a new {HaramiVidEventItemAssoc} is creasted).  Otherwise no change.
  #
  # @param harami1129 [Harami1129]
  # @param updates: [Array<Symbol>] Updated columns in Symbol; n.b., :uri is redundant b/c it is always read regardless.
  # @param force: [Boolean] if true, all the record values are forcibly updated (Def: false).
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {HaramiVid#columns_for_harami1129} for the returned value is set.
  # @return [Harami1129] {Translation} is associated via either {#translations} or {#unsaved_translations}
  #   Note the caller has no need to receive the return as the contents of self is modified anyway, though not saved, yet.
  # @raise [HaramiMusicI18n::MultiTranslationError::InsufficientInformationError] if a new record cannot be created.
  def set_with_harami1129(harami1129, updates: [], force: false, dryrun: false)
    self.columns_for_harami1129 = {:be4 => {}, :aft => {}}
    if updates.include?(:ins_link_root)
      uri2set = (harami1129.ins_link_root ? ApplicationHelper.uri_youtube(harami1129.ins_link_root) : nil)
      self.columns_for_harami1129[:be4][:ins_link_root] = uri
      self.uri = uri2set if uri.blank? || force
      self.columns_for_harami1129[:aft][:ins_link_root] = uri
    elsif self.new_record?
      msg = "(#{__method__}) HaramiVid is a new record, yet :ins_link_root is not specified (link_root=#{harami1129.link_root.inspect}, updates=#{updates.inspect}). Contact the code developer."
      raise HaramiMusicI18n::MultiTranslationError::InsufficientInformationError, msg
    end

    self.columns_for_harami1129[:be4][:ins_release_date] = release_date
    self.release_date = harami1129.ins_release_date if updates.include?(:ins_release_date) && (force || release_date.nil?)
    self.columns_for_harami1129[:aft][:ins_release_date] = release_date

#
#    ## EventItem (an Array of IDs is set to columns_for_harami1129; never nil but can be empty?)
#    self.columns_for_harami1129[:be4][:event_item] = (ar_id=event_items.ids)
#    self.columns_for_harami1129[:aft][:event_item] =
#      if harami1129.event_item && ar_id.empty?
#        event_items << harami1129.event_item if !dryrun || self.new_record?
#        [harami1129.event_item.id]
#      else
#        columns_for_harami1129[:be4][:event_item]
#      end
#
#    ## A {Place} may be assigned here
#    # self.place = Place['JPN'] if !place  # NOTE: Place['JPN'] used to be assigned unconditionally!
#    if !place && !columns_for_harami1129[:aft][:event_item].empty?  # the latter is equivalent to self.event_items.ids
#      # NOTE: self.reload or self.event_items cannot be used here because self may be a new_record?
#      self.place = EventItem.where(id: columns_for_harami1129[:aft][:event_item]).first.place
#    end
#    # NOTE: EventItem should be always defined in Harami1129 (after its internal_insert).
#    #   Therefore, no default Place is defined here. However, in practice, the default place
#    #   for EventItem defined from Harami1129 is still Japan, taken from config.
#    #   See Harami1129#set_event_item_ref which calls /app/models/concerns/module_guess_place.rb
#    #   which refers to config in Default.

    ## Translations

    self.columns_for_harami1129[:be4][:ins_title] = nil if self.new_record?
    return self if !updates.include?(:ins_title)

    all_trans = translations

    # If one or more Translation exists, whether it agrees or not, 
    # no Translation is added (let alone updated) unless force option is specified.
    return self if all_trans.size > 0 && !force && !dryrun

    # Even if force==true, if a matched Translation is found,
    # no new Translation is created (the validation would fail).
    all_trans.each do |ea_tra|
      if ea_tra.titles.include? harami1129.ins_title
        # Perfect match is the condition so far.  Can be improved.
        # Note langcode does not matter.
        #
        # Perfect match means this would be the identical value
        # to the one if the current ins_title was populated.
        self.matched_translation = ea_tra
        att = ((ea_tra.title == harami1129.ins_title) ? :title : :alt_title)
        ea_tra.matched_attribute = att
        self.matched_attribute   = att
        self.columns_for_harami1129[:be4][:ins_title] = matched_string
        self.columns_for_harami1129[:aft][:ins_title] = self.columns_for_harami1129[:be4][:ins_title].dup
        return self
      end
      #return self if ea_tra.titles.include? harami1129.ins_title
    end

    if all_trans.size > 0 && dryrun
      # A corresponding HaramiVid exists but the translation does not agree.
      best_tra = best_translations
      ea_tra = (best_tra['ja'] || best_tra['en'] || all_trans.first)
      self.matched_translation = ea_tra
      ea_tra.matched_attribute = :title
      self.matched_attribute   = :title
      self.columns_for_harami1129[:be4][:ins_title] = matched_string
      self.columns_for_harami1129[:aft][:ins_title] = self.columns_for_harami1129[:be4][:ins_title].dup
      return self
    end

    # Now, the situation is
    # either no corresponding Harami1129 is found OR
    # (the existing HaramiVid disagrees in the title with Harami1129#ins_title
    #  AND force=true).
    # Therefore,
    # a new Translation is now created, which will be saved when the instance is saved.
    trans = Translation.preprocessed_new(title: harami1129.ins_title, is_orig: true, translatable_type: self.class.name)
    trans.langcode = guess_lang_code(trans.title)
    #if unsaved_translations
    #  self.unsaved_translations.push trans
    #else
    #  self.unsaved_translations = [trans]
    #end
    self.unsaved_translations << trans
    self.unsaved_translations[-1].matched_attribute = :title
    self.matched_translation = trans
    self.matched_attribute   = :title
    self.columns_for_harami1129[:be4][:ins_title] ||= nil
    self.columns_for_harami1129[:aft][:ins_title] = harami1129.ins_title

    self
  end

  # Set EventItem association
  #
  # Also this may update {HaramiVid#place}. If not, self (=HaramiVid) is not updated.
  # Just an association HaramiVidEventItemAssoc and ArtistMusicPlay (HARAMIchan playing) may be created.
  #
  # @param harami1129 [Harami1129]
  # @param force: [Boolean] if true, all the record values are forcibly updated (Def: false).
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {HaramiVid#columns_for_harami1129} for the returned value is set.
  # @return [Harami1129] {Translation} is associated via either {#translations} or {#unsaved_translations}
  #   Note the caller has no need to receive the return as the contents of self is modified anyway, whether it is saved or not.
  def set_with_harami1129_event_item_assoc(harami1129, force: false, dryrun: false)
    self.columns_for_harami1129 ||= {:be4 => {}, :aft => {}}

    ## EventItem (an Array of IDs is set to columns_for_harami1129; never nil but can be empty?)
    self.columns_for_harami1129[:be4][:event_item] = (ar_id=event_items.ids)
    self.columns_for_harami1129[:aft][:event_item] =
      if harami1129.event_item && ar_id.empty?
        event_items << harami1129.event_item if !dryrun || self.new_record?  # HaramiVidEventItemAssoc is immediately created unless self is a new record
        [harami1129.event_item.id]
      else
        columns_for_harami1129[:be4][:event_item]  # identical to :be4
      end

    ## A {Place} may be assigned here
    # self.place = Place['JPN'] if !place  # NOTE: Place['JPN'] used to be assigned unconditionally!
    cand_evits = columns_for_harami1129[:aft][:event_item]
    if (!place || force) && !cand_evits.empty?  # the latter is equivalent to self.event_items.ids
      # NOTE: self.reload or self.event_items cannot be used here because self may be a new_record?
      self.place = EventItem.where(id: cand_evits).first.place
      save! if force || !dryrun
    end
    # NOTE: EventItem should be always defined in Harami1129 (after its internal_insert).
    #   Therefore, no default Place is defined here. However, in practice, the default place
    #   for EventItem defined from Harami1129 is still Japan, taken from config.
    #   See Harami1129#set_event_item_ref which calls /app/models/concerns/module_guess_place.rb
    #   which refers to config in Default.

    self
  end

  # Returns "music<br>music<br>..." for Home#index View
  #
  # @param langcode [String]
  # @return [String]
  def view_home_music(langcode)
    musics.map{|ea_mu|
      timing = timing(ea_mu)
      tit = ea_mu.title(langcode: langcode.to_s, lang_fallback: false, str_fallback: nil)
      if !tit && 'en' == langcode.to_s
        tit = ea_mu.romaji(langcode: 'ja')  # English fallback => Romaji in JA
        tit &&= '['+tit+']'
      end
      link_str = (tit.blank? ? '&mdash;' : ActionController::Base.helpers.link_to(tit, music_path(ea_mu)))
      hms_or_ms = sec2hms_or_ms(timing)
      ylink_en = link_to_youtube(hms_or_ms, uri, timing)  # defined in application_helper.rb
#ylink_en = link_to_youtube sprintf('%d'+I18n.t('s_time')+'—', (timing || 0)), uri, timing  # defined in application_helper.rb
      sprintf "%s (%s)", link_str, ylink_en
    }.join('<br>').html_safe
  end


  # Returns "artist1 + ……<br>artist2<br>..." for Home#index View
  #
  # where artist1 and artist2 are the links for {Artist},
  # whereas '……' is the link for {Music}
  #
  # @param langcode [String]
  # @return [String]
  def view_home_artist(langcode='en')
    musics.map{|ea_mu|
      arts = ea_mu.sorted_artists.uniq
      n_arts = arts.count
      art1st = arts[0]
      next '&mdash;'.html_safe if 0 == n_arts || art1st.unknown?
      tit = (art1st.title(langcode: langcode) || art1st.title)
      s1 = ActionController::Base.helpers.link_to(tit, artist_path(art1st))
      next s1 if 1 == n_arts
      s1+', '+ActionController::Base.helpers.link_to('……', music_path(ea_mu))
    }.join('<br>').html_safe
  end

  # @param include_self: [Boolean] If true (Def: false), self (HaramiVid) is included in return.
  # @return [HaramiVid::ActiveRecord_Relation] Other HaramiVids that share the same EventItem-s
  def other_harami_vids_of_event_items(include_self: false)
    hv_ids = event_items.ids
    ret = HaramiVid.joins(:event_items).where("event_items.id" => hv_ids)
    ret = ret.where.not("harami_vids.id" => id) if !include_self
    ret.distinct
  end

  # @param exclude_unknown: [Boolean] Unless false (Def: true), HaramiVids belonging to Event.unknown are excluded.
  #   In general, Event.unknown may inlucde thousands of EventItems and HaramiVids.
  #   Hence, if false, potentially thousands of HaramiVids may be returned, each of which
  #   may be processed thousands of times in /app/views/harami_vids/_other_harami_vids_table.html.erb
  #   where all HaramiVid in the same Event would be shown, i.e., if the video belongs to
  #   a default Event, the table would include hundreds of other HaramiVid-s that
  #   belong to the same default/unknown Event.
  #   This potentially leads to a memory error (now the Views are coded so that they limit the maximum
  #   number of rows displayed; then a memory error can be avoided).
  # @param include_self: [Boolean] If true (Def: false), self (HaramiVid) is included in return.
  # @return [HaramiVid::ActiveRecord_Relation] Other HaramiVids that share the same Event(s)
  def other_harami_vids_of_event(exclude_unknown: true, include_self: false)
    all_event_ids =
      if exclude_unknown
        events.reject{|ev| ev.default? || ev.unknown?}.map{|i| i.id}
      else
        events.ids
      end

    ret = HaramiVid.joins(:events).where("events.id" => all_event_ids)
    ret = ret.where.not("harami_vids.id" => id) if !include_self
    ret.distinct
  end

  # sets EventItem if self is for live_streaming and doee not have a significant EventItem
  #
  # If self appears to be for live-streaming, this method adds, this method
  # may create HaramiVidEventItemAssoc, and if it does, it is most likely
  # to create also a new {Event} and {EventItem}.
  # This method may also {#update} self.place.
  #
  # Specifically, if the existing {#event_item} does not exist (which should never happen
  # except for legacy records) or there is only one {#event_item} that is simply a default assigned one,
  # AND most importantly, 
  # self's (zero or one) EventItem .
  #
  # This method does nothing with the already associated (sole) {EventItem}.
  # However, this method copies all {ArtistMusicPlay} associated with the existing {EventItem}
  # to the new one.
  # Also, if +create_amps+ is given true, this methods creates a set of associations
  # {ArtistMusicPlay} for the newly associated (usually created) {EventItem},
  # for all Musics in {HaramiVidMusicAssoc} for the default Artist.
  #
  # This method mass-rewrite {Harami1129#event_item} to the new {EventItem} in default
  # when a new {EventItem} is created (see +transfer_h1129+).
  #
  # @param create_amps: [Boolean] If true, new {ArtistMusicPlay}-s are created
  #    if {HaramiVidMusicAssoc} exist.
  # @param transfer_h1129: [Boolean] if true (Def) and if HaramiVid is associated with a single
  #   EventItem that is associated with {Harami1129}-s, this method rewrites {Harami1129#event_item}
  #   of all of them to the newly created {EventItem}
  # @return [EventItem, NilClass] created EventItem if created, else nil.
  def set_event_item_if_live_streaming(create_amps: false, transfer_h1129: true)
    n_evits = event_items.count
    return if n_evits > 1 || (1 == n_evits && (evit_prev=event_items.first).event_group == (evgr=EventGroup.find_by_mname(:live_streamings)))
    # This method does nothing if HaramiVid is associated to more than 1 EventItem
    # (because EventItems for HaramiVid must have been manually manipulated by an Editor),
    # or if an EventItem's EventGroup is already Live-Streamings (to avoid duplicated
    # processing).

    evit = nil

    return_now = false
    ActiveRecord::Base.transaction(requires_new: true) do
      evit = _new_evit_if_live_streaming(evit_prev)
      if !evit
        return_now = true
        raise ActiveRecord::Rollback  # In Rails-7.2, escaping the transaction block with return would lead to commit of the DB transactions!
      end
      self.event_items << evit  # Creates a HaramiVidEventItemAssoc
      _copy_amps_to_new_evit(evit_prev, evit) if evit_prev  # Creates {ArtistMusicPlay}-s 
      _create_amps_from_hvmas(evit)  if create_amps         # Creates {ArtistMusicPlay}-s 
      _reset_h1129_evit_new(evit_prev, evit) if evit_prev && transfer_h1129
    end
    return if return_now

    evit.harami_vid_event_item_assocs.reset
    evit.artist_music_plays.reset
    evit
  end # def set_event_item_if_live_streaming

  # Returns a new EventItem if EventGroup is for streaming, else nil.
  #
  # This method does *not* check existing EventItem-s associated to self.
  #
  # @param evit_prev [EventItem, NilClass]
  # @return [EventItem, NilClass] if a new EventItem is appropriate (Group is for streaming), creates one and returns it; otherwise returns nil
  def _new_evit_if_live_streaming(evit_prev)
    title_ja = title_or_alt(langcode: :ja, lang_fallback_option: :either, str_fallback: "", article_to_head: true)
    place2pass, confidence = _get_place_and_confidence(title_ja)

    update!(place: place2pass) if place != place2pass

    ev_or_evit = EventItem.new_default(:HaramiVid, event: nil, place: place2pass, save_event: false, ref_title: title_ja, date: release_date, place_confidence: confidence)  # => EventItem or Event (unsaved if they are new)
    if !ev_or_evit  # should never happen...
      raise "nil is unexpectedly returned from EventItem.new_default(:HaramiVid, event: nil, place: #{place2pass ? place2pass.title : 'nil'}, save_event: false, ref_title: #{title_ja.inspect}, date: #{release_date.inspect}, place_confidence: #{confidence.inspect}), called from Event (ID=#{id}; title=#{title_or_alt(lang_fallback_option: :either, str_fallback: '').inspect})"
    end

    return if ev_or_evit == evit_prev

    if ev_or_evit.respond_to?(:unknown_event_item)  # if it is an Event
      return if ev_or_evit.event_group != (evgr ||= EventGroup.find_by_mname(:live_streamings))  # Ignores a different EventGroup from :live_streamings
      ev_or_evit.save!
      return ev_or_evit.unknown_event_item  # Event => EventItem
    elsif ev_or_evit.event_group == (evgr ||= EventGroup.find_by_mname(:live_streamings))
      logger.warning("WARNING(#{__method__}): EventItem (#{ev_or_evit.inspect}) unexpectedly has EventGroup[:live_streamings]; it should not have because a new Event is always created for EventGroup[:live_streamings] by Event.default, and such a case should have been already handled prior to this call.")
      return
    end

    # EventItem belongsing to an EventGroup of NOT :live_streamings
    nil
  end
  private :_new_evit_if_live_streaming

  # copies ArtistMusicPlay from the (sole) existing associated EventItem to the new one.
  #
  # @param evit_prev [EventItem]
  # @param evit [EventItem]
  def _copy_amps_to_new_evit(evit_prev, evit)
    evit = self.event_items.last
    evit_prev.artist_music_plays.each do |amp|
      next if evit.artist_music_plays.include? amp
      evit.artist_music_plays << amp.dup  # no errors raised if this fails for some reason.
    end
  end
  private :_copy_amps_to_new_evit

  # creates default {ArtistMusicPlay}-s for the specified {EventItem} based on {HaramiVidMusicAssoc}-s for self
  #
  # @param evit [EventItem]
  # @return [Array<ArtistMusicPlay>]
  def _create_amps_from_hvmas(evit)
    arret = []
    musics.uniq.each do |ea_mu|
      amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item: evit, music: ea_mu)
      next if evit.artist_music_plays.include? amp  # skips if the exact ArtistMusicPlay has been created in the previous step {#_copy_amps_to_new_evit}
      amp.save!
      arret << amp
    end
    arret
  end
  private :_create_amps_from_hvmas


  # reset {Harami1129#event_item} for the children of the existing (single) EventItem
  # associated to HaramiVid.
  #
  # Note that HaramiVid has other children Harami1129-s if and only if the consistency
  # among EventItem-s, HaramiVid, and Harami1129-s is somethow broken.  In the normal
  # circumstances, Harami1129 belongs_to only one HaramiVid and EventItem; therefore,
  # when HaramiVid is associated to only one EventItem at most (which is the condition
  # this method is called in the first place, because otherwise {#set_event_item_if_live_streaming}
  # would halt its operation at the beginning), +HaramiVid#event_items.first.harami1129s+
  # should agree with +HaramiVid#harami1129s+
  #
  # @param evit_prev [EventItem]
  # @param evit [EventItem]
  def _reset_h1129_evit_new(evit_prev, evit)
    evit_prev.harami1129s.each do |h1129|
      h1129.update!(event_item: evit)
    end
  end
  private :_reset_h1129_evit_new

  # Returns the most probable Place and its confidence (as defined in {Event.default})
  #
  # @return [Array<Place, Symbol>]
  def _get_place_and_confidence(title_ja)
    place = place
    def_place = Place.find_by_mname(:default_harami_vid)
    guessed_place = ((!place || (def_place == place)) ? Harami1129.guess_place(title_ja) : nil)

    if !place || [def_place, Place.unknown].include?(place)
      [guessed_place || def_place, :low]
    elsif place.unknown?  # manually specified, but Place is unknown? in a significant country other than the default Country, e.g., Country["GBR"].unknown_place and Country["JPN"].prefectures.third.unknown_place
      [place, :medium]
    else
      [place, :high]  # user has manually defined it.
    end
  end
  private :_get_place_and_confidence


  ########## Before-validation callbacks ##########

  # Callback before_validation
  #
  # This should not be invoked - Controllers should take care of.
  def add_def_channel
    self.channel ||= Channel.primary
  end

  # Callback before_validation
  #
  # saving uri in DB like
  #   "youtu.be/WFfas92FA?t=24"
  # as opposed to
  #   "youtube.com/shorts/WFfas92FA?t=24"
  #   "https://www.youtube.com/watch?v=WFfas92FA?t=24s&link=youtu.be"
  #   "https://www.youtube.com/live/vXABC6EvPXc?si=OOMorKVoVqoh-S5h?t=24"
  #
  # In fact, time-query-parameter is not recommended...
  #
  # @return [String, NilClass]
  def normalize_uri
    self.uri = normalized_uri
  end
 
  # (distinct) Musics that exist in HaramiVidMusicAssocs but not in ArtistMuscPlays
  #
  # Kind of reverse of {#missing_musics_from_hvmas}
  #
  # @param artist [Artist] if specified, returns the missing Musics from ArtistMuscPlays for the Artist
  # @return [Music::ActiveRecord_Relation]
  def missing_musics_from_amps(artist: nil)
    amp_rela = Music.joins(artist_music_plays: {event_item: :harami_vid_event_item_assocs}).where("harami_vid_event_item_assocs.harami_vid_id" => id)
    amp_rela = amp_rela.where("artist_music_plays.artist_id" => artist.id) if artist
    existing_ids = amp_rela.distinct.ids
    ## NOTE: self.musics.where.not(...) would raise:  PG::InvalidColumnReference: ERROR:  for SELECT DISTINCT, ORDER BY expressions must appear in select list
    Music.joins(:harami_vid_music_assocs).where("harami_vid_music_assocs.harami_vid_id" => id).where.not("musics.id" => existing_ids).distinct
  end

 
  # (distinct) Musics that exist in ArtistMuscPlays but not in HaramiVidMusicAssocs
  #
  # Kind of reverse of {#missing_musics_from_amps}
  #
  # @param event_item [EventItem] if specified, returns the missing Musics from ArtistMuscPlays for the EventItem
  # @return [Music::ActiveRecord_Relation]
  def missing_musics_from_hvmas(event_item: nil)
    existing_ids = Music.joins(:harami_vid_music_assocs).where("harami_vid_music_assocs.harami_vid_id" => id).distinct.ids
    hs_where = {"harami_vid_event_item_assocs.harami_vid_id": id}
    hs_where.merge!( {"event_items.id": event_item.id} )  if event_item
    Music.joins(artist_music_plays: {event_item: :harami_vid_event_item_assocs}).where(**hs_where).where.not("musics.id" => existing_ids).distinct
  end

  # Total number of inconsistent Musics for self
  #
  # @example to find all HaramiVids with inconcistency
  #    HaramiVid.all.find_all{|record| record.n_inconsistent_musics > 0}
  #
  # @return [Integer]
  def n_inconsistent_musics
    missing_musics_from_amps.count + missing_musics_from_hvmas.count
  end

  private    ################### Callbacks

    def add_default_place
      self.place = (DEF_PLACE || Place.first) if !self.place
    end

    # Channel is automatically associated with Translations after_create
    def save_unsaved_associates  # callback to create(-only) 
      are_new = {
        channel: false,
        event_item: false, 
        artist: false,
        music: false,
      }
      @unsaved_channel && are_new[:channel]=true && @unsaved_channel.save!
      @unsaved_event_item && are_new[:event_item]=true && @unsaved_event_item.save!
      @unsaved_artist  && are_new[:artist]=true  && @unsaved_artist.save!
      @unsaved_music   && are_new[:music]=true   && @unsaved_music.save!

      if are_new[:music]
        save_harami_vid_music_assoc
      end
      if are_new[:artist] || are_new[:music]
        save_engage
      end
      if are_new[:artist] || are_new[:music] || are_new[:event_item]
        save_artist_music_play
      end
    end

    # Channel is automatically associated with Translations after_create
    def save_harami_vid_music_assoc  # method called from callback to create(-only) 
      return if !@unsaved_music
      if @unsaved_musici.new_record?
        errors.add :base, "Music cannot be handled for an unknown reason... Contact the code developer."  # desirable to define this in case the Exception is caught somewhere upstream in the future.
        msg = "ERROR(#{File.basename __FILE__}:#{__method__}): @unsaved_music is strange: #{@unsaved_music.inspect}" 
        logger.error msg
        raise msg
      end

      hvma = HaramiVidMusicAssoc.find_or_initialize_by(harami_vid: self, music: @unsaved_music)
      hvma.timing = music_timing.to_i if music_timing.present?  # it has been validated to be numeric if present.
      if result = hvma.save
        msg = "Something goes wrong in saving Music-Video association"
        errors.add :music_name, msg
        logger.error msg
        raise msg
      end
    end

    # Channel is automatically associated with Translations after_create
    def save_engage  # method called from callback to create(-only) 
      eng = engage.find_or_initialize_by(music: @unsaved_music, artist: @unsaved_artist)
      eng.timing = music_timing.to_i if music_timing.present?
      eng.save!
    end

end


class << HaramiVid
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, uri: nil, **kwds, &blok)
    uri ||= "https://example.com/"+(0...8).map{(65 + rand(26)).chr}.join
    create_basic_bwt!(*args, uri: uri, **kwds, &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  # Unlike {#create_basic!}, an existing Sex is used, which is assumed to exist.
  def initialize_basic(*args, uri: nil, **kwds, &blok)
    uri ||= "https://example.com/"+(0...8).map{(65 + rand(26)).chr}.join
    initialize_basic_bwt(*args, uri: uri, **kwds, &blok)
  end
end


