# coding: utf-8

# == Schema Information
#
# Table name: harami1129s
#
#  id                                                    :bigint           not null, primary key
#  checked_at(Insertion validity manually confirmed at)  :datetime
#  id_remote(Row number of the table on the remote URI)  :bigint
#  ins_at                                                :datetime
#  ins_link_root                                         :string
#  ins_link_time                                         :integer
#  ins_release_date                                      :date
#  ins_singer                                            :string
#  ins_song                                              :string
#  ins_title                                             :string
#  last_downloaded_at(Last-checked/downloaded timestamp) :datetime
#  link_root                                             :string
#  link_time                                             :integer
#  not_music(TRUE if not for music but announcement etc) :boolean
#  note                                                  :text
#  orig_modified_at(Any downloaded column modified at)   :datetime
#  release_date                                          :date
#  singer                                                :string
#  song                                                  :string
#  title                                                 :string
#  created_at                                            :datetime         not null
#  updated_at                                            :datetime         not null
#  engage_id                                             :bigint
#  event_item_id                                         :bigint
#  harami_vid_id                                         :bigint
#
# Indexes
#
#  index_harami1129s_on_checked_at                        (checked_at)
#  index_harami1129s_on_engage_id                         (engage_id)
#  index_harami1129s_on_event_item_id                     (event_item_id)
#  index_harami1129s_on_harami_vid_id                     (harami_vid_id)
#  index_harami1129s_on_id_remote                         (id_remote)
#  index_harami1129s_on_id_remote_and_last_downloaded_at  (id_remote,last_downloaded_at) UNIQUE
#  index_harami1129s_on_ins_link_root_and_ins_link_time   (ins_link_root,ins_link_time) UNIQUE
#  index_harami1129s_on_ins_singer                        (ins_singer)
#  index_harami1129s_on_ins_song                          (ins_song)
#  index_harami1129s_on_link_root_and_link_time           (link_root,link_time) UNIQUE
#  index_harami1129s_on_orig_modified_at                  (orig_modified_at)
#  index_harami1129s_on_singer                            (singer)
#  index_harami1129s_on_song                              (song)
#
# Foreign Keys
#
#  fk_rails_...  (engage_id => engages.id) ON DELETE => restrict
#  fk_rails_...  (event_item_id => event_items.id)
#  fk_rails_...  (harami_vid_id => harami_vids.id)
#
class Harami1129 < ApplicationRecord
  extend  ModuleCommon
  include ModuleCommon  # preprocess_space_zenkaku etc
  include ModuleGuessPlace  # for guess_place

  # Prefix for the column names inserted from the raw columns
  PREFIX_INSERTED_WITHIN = 'ins_'

  # Regular Expression for the prefix for the column names inserted from the row columns
  RE_PREFIX_INSERTED_WITHIN = /\A#{Regexp.quote PREFIX_INSERTED_WITHIN}/

  # All the ins_* columns (except ins_at), which are populated to other tables.
  ALL_INS_COLS = %i(ins_title ins_singer ins_song ins_release_date ins_link_root ins_link_time)

  # All the directly downloaded columns (Symbol-s)
  ALL_DOWNLOADED_COLS = %i(title singer song release_date link_root link_time)

  # All the directly downloaded columns (String-s)
  ALL_DOWNLOADED_COLS_STR = ALL_DOWNLOADED_COLS.map(&:to_s)

  # UTF-8 symbols/markers for Harami1129 index table.
  #
  # Originally, `orig_modified_at` and `ins_at` used to be compared.
  # However, their relation is no longer referred to, because ins_at
  # can be confusing when only one of the values are inserted, etc.
  TABLE_STATUS_MARKER = {
    no_insert: "\u274c", # Cross:  Not inserted (!`ins_at`); n.b., the following is all insterted cases
    org_inconsistent: "\u2757", # Heavy exclamation: the original has been updated since the last check and original and destination are not consistent. Need to check if the record needs updating.
      # (`!checked_at` || `checked_at` < `orig_modified_at`) && (!= ins_*) && inconsistent(org)
    ins_inconsistent: "\u2753", # Black Question: the original has been updated since the last check and ins_* and destination are inconsistent, whereas org and the latter are consistent. So basically, ins_* is recommended to be updated to avoid confusion (though not compulsory). Basically, this happens when our editor has updated our record (to correct something) and the remote Harami1129 editor separately made the same modification, which would leave only ins_* to be incorrect.
      # (`!checked_at` || `checked_at` < `orig_modified_at`) && (!= ins_*) && inconsistent(ins)
    consistent: "\u2713", # Check: destination and both original and ins_* are consistent with the destination, though unchecked since the last update. Nothing is required to be done, though to "check" is recommended.
      # (`!checked_at` || `checked_at` < `orig_modified_at`) && same-destinations
    checked: "\u2705", # White Heavry check, Inserted and checked
      # `checked_at` && `checked_at` >= `orig_modified_at`
  }

  # Used in Harami1129 index Views
  TABLE_STATUS_MARKER_DESCRIPTION = {
    no_insert: "Within-table insertion to the corresponding ins_* cell has not been conducted.",
    org_inconsistent: "Since the last 'Confirm', the downloaded original has been updated and it differs from that in the corresponding destination table. Check out ins_* and destination. To jump to Singer/Song in the DB entry, open the Engage column for the link, and to Title/URL/Date, open the Vid column.",
    ins_inconsistent: "Same as '#{TABLE_STATUS_MARKER[:org_inconsistent]}' except the downloded data somehow agrees with the destination, which leaves only the corresponding 'ins_*' being different. To check out, open 'ins_*' columns.",
    consistent: "Original, ins_* and destination are all consistent. You may 'Confirm'.",
    checked: "No update has been made since this row was 'Confirm'-ed by a moderator.",
  }

  # Prefix for column names
  PREFIX_INS = "ins_"

  attr_accessor :destroy_engage
  attr_accessor :human_check
  attr_accessor :human_uncheck

  # Returns a Harami1129 column name for Artist or Music
  #
  # @example
  #    Harami1129.model2harami1129_colname("artist")           # => "singer"
  #    Harami1129.model2harami1129_colname(Artist, ins: true)  # => "ins_singer"
  #    Harami1129.model2harami1129_colname(Music.first)        # => "song"
  #
  # @param modelname [String, Symbol, ApplicationRecord, Class]
  # @param ins: [Boolean] if true (Def: false), "ins_" is prefixed
  # @return [String]
  def self.model2harami1129_colname(modelname, ins: false)
    modelname_str =
      if    modelname.respond_to?(:name)  # e.g., Artist
        modelname.name.underscore
      elsif modelname.respond_to?(:saved_changes)  # e.g., Artist.third
        modelname.class.name.underscore
      else
        modelname.to_s
      end

    colname_root =
      case modelname_str
      when "artist"
        "singer"
      when "music"
        "song"
      else
        raise "Should not happen (colname_root=#{colname_root.inspect}). Contact the code developer."
      end

    (ins ? PREFIX_INS : "") + colname_root
  end

  # Order of "INS" Columns displayed in Views index table
  #
  #   [:ins_title, :ins_singer, :ins_song, :ins_release_date, :ins_link_root, :ins_link_time]
  TABLE_INS_COLUMNS_ORDER = %w(title singer song release_date link_root link_time).map{|i| (PREFIX_INS+i).to_sym}

  # Order of the default time-related columns (in case some of them are the same)
  DEF_TIME_COLUMN_ORDERS = [
    :created_at,
    :last_downloaded_at,
    :orig_modified_at,
    :ins_at,
    :checked_at,
    :updated_at,
  ]

  ## Insertion/populaiton status of each row (for use of cache)
  #HS_STATUS_ROW = {}

  attr_accessor :place  # Add a guessed Place if guessed at all.

  # Hold a return value of a row-status-check
  class PopulateStatus
    using ModuleHashExtra  # for extra methods, e.g., Hash#values_blank_to_nil

    # Hash of {SymColumnName => SymbolStatus}
    # The value is one of the keys in {Harami1129::TABLE_STATUS_MARKER}
    #
    # @example to get Array of column name Symbols for a Status
    #   ps.status_cols.find_all{|k,v| v == :inconsistent}.to_h.keys
    attr_reader :status_cols

    # updated_at of the corresponding record.
    # Used by the externatl entity to judge if their cache can be used.
    attr_reader :updated_at

    # Hash of Target models once populated from the current status of Harami1129 (NOT the currently linked ones, though they agree in most cases)
    attr_accessor :tgt

    # Current HaramiVidMusicAssoc (single record)
    attr_accessor :hvma_current

    # @param sym_or_hs [Symbol, Hash] if Hash, {SymColumnName => SymbolStatus}; if Symbol, all the columns have the same status.
    # @param h1129_ins [Harami1129] Unsaved and only ins_* are filled; they are the current ins_* if unmodified, or ins_* inserted from the current original if modified.
    # @param dest [Hash] current String repretentation of the destination as Hash
    # @param dest_to_be [Hash] 
    # @param tgt: [Hash<ActiveRecord>] (:harami_vid => Target ActiveRecord) etc. Record may be nil or have nil id.
    # @param updated_at: [Time] updated_at of the corresponding record.
    def initialize(sym_or_hs, h1129_ins, dest: nil, dest_to_be: nil, tgt: {}, hvma_current: nil, updated_at: Time.now)
      @status_cols = (sym_or_hs.respond_to?(:merge) ? sym_or_hs : Harami1129::ALL_INS_COLS.map{|i| [i, sym_or_hs]}.to_h).with_sym_keys
      @h1129_ins = h1129_ins
      @dest       = (dest && dest.with_sym_keys)  # destination (current status)
      @dest_to_be = (dest_to_be && dest_to_be.with_sym_keys)  # destination if populated (meaningful only if it has not been popularted)
      @tgt        = tgt.with_indifferent_access               # destination ActiveRecord if populated
      @hvma_current = hvma_current
      @updated_at = updated_at
    end

    # @param col [Symbol] e.g., ins_singer
    # @return [Symbol] e.g., :consistent
    def status(col)
      @status_cols[col.to_sym]
    end

    # @param col [Symbol] e.g., ins_singer
    # @return [String] e.g., "\u2705"
    def marker(col)
      Harami1129::TABLE_STATUS_MARKER[status(col)]
    end

    # @param col [Symbol] e.g., ins_singer
    # @return [Object] they are the current ins_* if unmodified, or ins_* inserted from the current original if modified as a result of a new download.
    def ins_to_be(col)
      @h1129_ins.send col
    end

    # @return [Hash<Symbol, Object>] ins_* values as in {#ins_to_be} in Hash
    def ins_to_be_all
      @h1129_ins.slice(*Harami1129::ALL_INS_COLS)
    end

    # @param col [Symbol] e.g., ins_singer
    # @return [Object] value of current String repretentation of the destination
    def dest_current(col)
      @dest ? @dest[col.to_sym] : nil
    end
    alias_method :destination, :dest_current if ! self.method_defined?(:destination)

    # @return [Hash<Symbol, Object>] Current destination values as in {#dest_current} in Hash
    def destinations
      @dest
    end

    # @param col [Symbol] e.g., ins_singer
    # @return [Object] value of the String repretentation of the destination once populated (meaningful only if it has not been popularted)
    def dest_to_be(col)
      @dest_to_be ? @dest_to_be[col.to_sym] : nil
    end

    # Returns a sorted Array of status or markers
    #
    # Sorted in the order of the worst first according to {Harami1129::TABLE_STATUS_MARKER}.
    # The result is uniq-qed.
    #
    # This method is helps the caller easily identify the worst-possible status.
    #
    # @example
    #   h1129.populate_status.status_cols
    #   # => {ins_title: consistent, ins_singer: consistent, ins_song: org_inconsistent,
    #         ins_release_date: consistent, ins_link_root: consistent, ins_link_time: consistent}
    #   h1129.populate_status.status_cols.sorted_status
    #   # => [:org_inconsistent, :consistent]
    #
    # @param return_markers [Boolean] if true (Def: false), returns an Array of {#marker}
    # @return [Array<Symbol, String>]
    def sorted_status(return_markers: false)
      skeys = Harami1129::TABLE_STATUS_MARKER.keys
      ret = status_cols.values.uniq.sort{|a,b|
        skeys.find_index(a) <=> skeys.find_index(b)
      }
      return_markers ? ret.map{|i| Harami1129::TABLE_STATUS_MARKER[i]} : ret
    end

    # Returns the problematic column names
    #
    # Problematic statuses are (cf., {Harami1129::TABLE_STATUS_MARKER}:
    #
    # * no_insert
    # * org_inconsistent
    # * ins_inconsistent
    #
    # The results is sorted according to {Harami1129::TABLE_INS_COLUMNS_ORDER},
    # converted into a string as appearing in the table header, e.g.,
    # "+Ins link time+" from "+ins_link_time+".
    #
    # @return [Array<String>]
    def problematic_column_names
      status_cols.map{|k, v|
        # These are regarded as "problematic"
        %i(no_insert org_inconsistent ins_inconsistent).include?(v) ? k : nil
      }.compact.sort{|a, b|
        Harami1129::TABLE_INS_COLUMNS_ORDER.find_index{|i| i == a} <=>
        Harami1129::TABLE_INS_COLUMNS_ORDER.find_index{|i| i == b}
      }.map{|i| i.to_s.capitalize.tr("_", " ")}
    end
  end # class PopulateStatus


  # Perform the {#populate_status} check of self and cache it.
  #
  # cache is implemented as this will be called repeatedly
  # by the index View (through Grids).
  # Since it uses the {#updated_at} information, if self
  # has been updated since the last caching, the cache is
  # automatically discarded even if use_cache is true.
  #
  # @param use_cache [Boolean] if true (Def) and if cache is available, returns it.
  # @return [Harami1129::PopulateStatus]
  def populate_status(use_cache: true)
    return @populate_status if use_cache &&
                               @populate_status &&
                               @populate_status.updated_at >= updated_at

    upd_hash = (get_upd_hash(force: false) || {}) # ins_* values if updated with internal_insertion
    h1129_ins = Harami1129.new(**upd_hash)
    ALL_INS_COLS.each do |col|
      h1129_ins.send(col.to_s+"=", send(col)) if h1129_ins.send(col).blank?
    end

    begin
      h1129_ins_now   = Harami1129.new(**(ALL_INS_COLS.map{|k| [k, send(k)]}.to_h))
      h1129_ins_to_be = get_h1129_ins_to_be
      return(ret = PopulateStatus.new(:no_insert, h1129_ins_to_be, updated_at: updated_at)) if ins_at.blank?

      #stat_sym = ((ins_at < (orig_modified_at || updated_at || Time.new(0))) ? :updated : :inconsistent)

      messages = []
      populate_ins_cols(updates: ALL_INS_COLS, messages: messages, dryrun: true) # sets @columns_at_destination
      #self.reload

      return(ret = PopulateStatus.new(:checked, h1129_ins_to_be, dest: columns_at_destination[:be4].dup, dest_to_be: columns_at_destination[:aft].dup, tgt: columns_at_destination[:tgt].dup, hvma_current: columns_at_destination[:hvma_current], updated_at: updated_at)) if checked_at && orig_modified_at <= checked_at  # Already eye-checked

      hs2pass = {}
      ALL_INS_COLS.each do |col|
        hs2pass[col] =
          if    columns_at_destination[:be4][col] != h1129_ins_to_be.send(col)
            :org_inconsistent
          elsif columns_at_destination[:be4][col] != h1129_ins_now.send(col)
            :ins_inconsistent
          else
            :consistent
          end
      end
      return(ret = PopulateStatus.new(hs2pass, h1129_ins_to_be, dest: columns_at_destination[:be4].dup, dest_to_be: columns_at_destination[:aft].dup, tgt: columns_at_destination[:tgt].dup, hvma_current: columns_at_destination[:hvma_current], updated_at: updated_at))
    ensure
      @populate_status = ret
    end

  end

  def get_h1129_ins_to_be
    h1129_ins_to_be = Harami1129.new()
    ActiveRecord::Base.transaction(requires_new: true) do
      fill_ins_column!(force: true)
      ALL_INS_COLS.each do |col|
        h1129_ins_to_be.send(col.to_s+"=", send(col))
      end
      raise ActiveRecord::Rollback, "Force rollback."
    end
    self.reload
    h1129_ins_to_be
  end
  private :get_h1129_ins_to_be


  # Array of the Symbol keys of the updated columns in fill_ins_column!
  # Note the keys of {#saved_changes} are String.
  attr_accessor :updated_col_syms

  # Hash of Symbols(:ins_title etc) => Destination-representation;
  # e.g., [:be4, :aft] => :ins_singer => 'Beatles, The'
  # where, the name is {Artist#title} corresponding to {#ins_singer}.
  attr_accessor :columns_at_destination

  belongs_to :harami_vid, optional: true
  belongs_to :event_item, optional: true
  belongs_to :engage,     optional: true
  # NOTE: There are technically two ways to get Music (but use the former!):
  #   * self.engage.music
  #   * self.harami_vid_music_assoc.music
  # where the latter internally calls the former (and therefore must be consistent with the former).

  has_many :harami1129_reviews, dependent: :nullify # Ideally, (dependent: :restrict_with_exception), meaning in DB "on_delete: :restrict". If it was the case, before the corresponding Harami1129 is destroyed, either harami1129_id in Harami1129Review should be updated for another Harami1129 or Harami1129Review record should be simply destroyed as irrelevant any more.  However, so far, it is only nullify, so moderators can destroy Harami1129 easily.

  validate :at_least_one_entry
  validates_uniqueness_of     :link_root, scope:     :link_time, allow_nil: true
  validates_uniqueness_of :ins_link_root, scope: :ins_link_time, allow_nil: true

  # nil is allowed for :id_remote and :last_downloaded_at in the DB-level but prohibited in Rails.
  validates_numericality_of :id_remote, greater_than: 0, allow_nil: false
  validates                 :last_downloaded_at, presence: true
  validates_uniqueness_of   :id_remote, scope: :last_downloaded_at

  # Get HaramiVidMusicAssoc
  #
  # @todo This calls SQL twice.
  #
  # @return [HaramiVidMusicAssoc, NilClass] nil if this is not Music or has no HaramiVid associated.
  def harami_vid_music_assoc
    harami_vid.harami_vid_music_assocs.where(music: engage.music).first
  end


  # Manual version of {#Harmai1129.create} to make sure all the necessary columns are specified
  #
  # Use it as a substitute of Harami1129.create (especially in testing)
  #
  # For most columns, the standard Model validations should take care of.
  # But some of them can be nil; if they are deliberately specified to be nil
  # in manual creation, that is fine.  But if not, it would be unintentional
  # and might be just forgotten. The purpose of this method is to check the possibility.
  #
  # @note Type of each column etc is not checked, which should be validated by the model.
  #   In reality, you'd need last_downloaded_at which is not checked in this routine.
  #   Also, Integer id_remote is required.
  #
  # @return [Harami1129] Model#create always returns a model, whose id would be nil if validation has failed.
  def self.create_manual(**opts)
    arkey = opts.keys.map(&:to_sym)
    missings = []
    ALL_DOWNLOADED_COLS.each do |colname|
      missings.push colname.to_s if !arkey.include? colname
    end
    raise "ERROR(#{__FILE__}:#{__method__}): Missing column names in #{self.name}.create: #{missings.inspect}" if !missings.empty?
    create(**opts)
  end

  # Destructive version of {#Harmai1129.create_manual}
  #
  # Use it as a substitute of Harami1129.create!
  #
  # @return [Harami1129]
  def self.create_manual!(**opts)
    mdl = create(**opts)
    mdl.save!
    mdl
  end


  # Create/update the record, along with last_downloaded_at.
  #
  # updated_at unchanges if only the change is last_downloaded_at
  #
  # @param prms [Hash] to give {#create!}
  # @return [Harami1129]
  # @raise [ActiveRecord::RecordInvalid] etc if the given parameters are invalid.
  def self.insert_a_downloaded!(**prms)
    # Without "if_needed:", presense validation would fail.
    hs_if_needed = (!prms.key?(:last_downloaded_at)  ? {last_downloaded_at: Time.now} : {})
    update_or_create_by_with_notouch!(prms, [:link_time, :link_root], if_needed: hs_if_needed){ |record|
      record.last_downloaded_at = (record.saved_change_to_updated_at? ? record.updated_at : Time.now)
      record.orig_modified_at = record.last_downloaded_at if record.saved_change_to_updated_at?
    }
  end

  # Reverse of {#ins_column_key}
  #
  # @param ins_key [Symbol, String] the ins_* key, e.g., "ins_link_root"
  # @return [Symbol] e.g., :link_root
  def self.downloaded_column_key(ins_key)
    (ins_key.to_s).sub(Harami1129::RE_PREFIX_INSERTED_WITHIN, '').to_sym
  end

  # Get the Symbol column name of :ins_singer etc
  #
  # @param key_orig [Symbol, String] the original key, e.g., "link_root"
  # @return [Symbol] ins_* key, e.g., :ins_link_root
  def ins_column_key(key_orig)
    (PREFIX_INSERTED_WITHIN+key_orig.to_s).to_sym
  end

  # Fill ins_* columns and populate them to other tables.
  #
  # == Algorithm
  #
  # The {Translation} for each Model is tightly associated to the model; therefore {Translation}
  # must be created (or updated, if required) simultaneously in create of any instance.
  # The other associations are, except for {Harami1129}'s belongs_to {HaramiVid},
  # many to many.  Therefore, in create (rather than update), each instance can be created,
  # ignoring the potential associations (n.b., {HaramiVid} has_many {Harami1129} and NOT
  # belongs_to, and hence even {HaramiVid} can be created independently of the ohters).
  # Then the intermediate records ({Engage} and {HaramiVidMusicAssoc}) are created afterwards.
  #
  # In short,
  #
  # (1) {HaramiVid}: URI-related, date, place
  # (2) {Music}: Title ({Translation})
  # (3) {Artist}: Title ({Translation})
  # (3) {EngageHow}:
  # (5) {HaramiVidMusicAssocs}: (3-way association; HaramiVid, Music, timing, though there should be no multiple timings, even though there are no Rails/DB restriction in place for it)
  # (6) {Engage}: (Association; unkown)
  # (7) {EventItem}: (an existing unknown one is used. making sure to match the one pointing to the same HaramiVid or ins_link_root)
  # (8) {HaramiVidEventItemAssoc}
  # (9) {ArtistMusicPlay} (containing :event_item :artist :music :play_role :instrument)  if not existent
  #
  # == Schematic view
  #
  #   Harami1129:
  #      singer,   song, timing, title(Video);date;uri
  #          (Engage)            (HaramiVid)
  #     (Artist) (Music)
  #      (Trans) (Trans)         (Trans)
  #      (EngageHow) (HaramiVidMusicAssoc(timing))
  #
  #   HaramiVid (Translation(title)):
  #     has_many Harami1129, HaramiVidMusicAssoc(timing) => Music => EngageHow1(Artist1, Artist2), EngageHow2()
  #              Harami1129, HaramiVidMusicAssoc(timing) => Music => EngageHow1(Artist2),          EngageHow2()
  #                                                        (Trans)              (Trans)  (Trans)
  #
  #   EventItem (no Trans):
  #     has_many (many-to-many) HaramiVid
  #     has_many Harami1129
  #     has_many ArtistMusicPlay => Artist/Music/PlayRole/Instrument (all Trans)
  #
  # == Description
  #
  # The basic idea is that once the downloaded data have been populated
  # among several DB tables, they should not be updated with automatic
  # processing even if the newly downloaded data are different from
  # those saved in the DB tables, excepting the null columns in the
  # populated data in the DB tables.
  #
  # So, we need a web interface for moderators to judge whether any change
  # in the newly downloaded data is reflected in the existing DB tables.
  # Also, we need to record the judgement by moderators so that moderators
  # would not be prompted to check the same matter again.
  #
  # The Harami1129 table has the column +checked_at+ and +orig_modified_at+.
  # The latter (+orig_modified_at+) is updated every time any of the downloaded data
  # have changed since the last time.
  # In addition, for the sake of performance and convenience for human checking, it has a few columns:
  # ins_title, ins_song, ins_singer, ins_release_date, ins_link_root, ins_link_time,
  # together with the time +ins_at+, the time when the insertion was performed.
  # They are set when the first insertion/injection/population to DB tables
  # are performed; their contents are basically the same as they are injected
  # to other DB tables, maybe somewhat modified from the corresponding columns
  # of the downloaded data at the time. For example, extra spaces contained in
  # the original downloaded titles are truncated and/or trimmed. They will remain
  # unchanged even if the downloaded columns have changed until the forced manual
  # update is performed by a moderator.
  #
  # These columns except +checked_at+ are not essential though useful
  # for performance sake.
  # Every time downloading is initiated, {DownloadHarami1129sController} does:
  #
  # (1) +last_downloaded_at+ is always updated.
  # (2) If the downloaded row is a new one or has a difference from an existing one,
  #     +orig_modified_at+ is updated.
  # (3) If it is a new row, automatic injection to other DBs is performed.
  # (4) If the downloaded row contains a datum any of +ins_*+ columns does not have,
  #     it is automatically populated to the +ins_*+ columns and +ins_at+ is updated.
  # (5) If the downloaded row contains a datum that is *insignificantly* different from that
  #     in the corresponding existing (downloaded) column but basically is the same as
  #     in the corresponding existing (+ins_*+) column, and if none of the other columns
  #     have changed, and if +checked_at+ is not earlier than +orig_modified_at+, then
  #     +orig_modified_at+ and +checked_at+ are updated to the current time, the same
  #     as +updated_at+ (by save! without changing the two time columns and then
  #     {#save!}(touch: false) after substituting +updated_at+ to the two time columns.
  # (6) (TODO: Advanced) For the existing row, if the downloaded row contains a datum that is different
  #     from that in the corresponding +ins_at+ column but if the downloaded datum
  #     is consistent with the to-be-populated destination (because our site editor
  #     has corrected typos etc), that means the corresponding +ins_*+ one is the only +wrong+ one
  #     (among the original, inserted, and populated). In this case, internal insertion is performed and
  #     +orig_modified_at+ and +ins_at+ are updated. If the original +checked_at+
  #     is the same as +orig_modified_at+ (namely there are no other anomalies), it is updated, too.
  #
  # For existing rows, manual populating is prompted to moderators if:
  #
  # (1) +checked_at+ is nil or earlier than +orig_modified_at+ (the downloaded data have been altered but the alteration have not been reflected in +ins_*+ and thus other DB tables).
  # (2) +checked_at+ is nil or earlier than +ins_at+ (all or part of the data have been automaticaly populated to other DBs but they have not been eye-checked).
  #
  # After populating records (to other DB tables), two foreign keys of
  # *harami_vid_id* and *engage_id* are set. The latter indicates
  # which singer (artist) is listed in {Harami1129} - without it
  # there would be no way to tell what the corresponding artist is because
  # each music may be *engaged* by multiple artists.
  #
  # The populating of the data to other DBs works like this (everything is inside a Transaction if they are performed in one go):
  #
  # (1) Check if +harami_vid_id+ and +engage_id+ are set
  #     (1) If so, get the destination records by {#find}
  #     (2) If not, call {HaramiVid.find_one_for_harami1129} etc to get a record, whether existing or new.
  #         (1) In {HaramiVid}, if an existing HaramiVid has the same URI (the converted {Harami1129#ins_link_root} is {HaramiVid#uri}), it is returned, where title may differ. If not, a blank new record is returned.
  #     (3) {Engage} is not called at this stage
  # (2) For the returned record, send {#HaramiVid#set_with_harami1129} etc with "updates" array, specifying which columns should be updated (the moderator should have a choice if manual update).  Then, the new parameters are set in the record (though not saved yet)
  #     (1) In {HaramiVid}, :ins_title, :ins_release_date
  #         (1) maybe unsaved_translations
  #     (2) Call {Engage}, if either (or both) of :ins_singer, :ins_song is updated,
  #         (1) If either {Artist} or {Music} to be updated is different from those in the existing {Engage} linked to {Harami1129}, then a different {Engage} will be returned, which may or may not have already existed in the DB.
  #         (2) Music or Artist names in our DB cannot be modified in this process (they have to be updated separately if need be). Only the things that can be modified with this are association and possibly creations of new Artist/Music (and related {Translation}). For example, if the {Artist} in the previous record was wrong (either a different Artist or mis-spelled) and is now modified in Harami1129, {Harami1129#engage} can be altered, but the wrong {Artist} remains in the DB, whether {Artist#title} is correct or not (lie misspelled).
  #         (3) The returned {Engage} is already saved in the DB (use a wrapper Transaction if rollback is the possibility)
  # (3) save (if everything is OK, which should always be the case). This should be carried out in a transaction.
  #     (1) {HaramiVid#save!}
  #     (2) {Harami1129.harami_vid} = harami_vid
  #     (3) {Harami1129.engage} = returned_engage
  #     (4) {HaramiVid#musics} << {Engage#music} to create an entry {HaramiVidMusicAssoc} with the specified timing ({HaramiVid#ins_link_time}) if not exists. Note that if {Harami1129#ins_link_time} differs from the existing {HaramiVidMusicAssoc}, {HaramiVidMusicAssoc#timing} is updated because there should be only one per {HaramiVid} per {Music}, although {Harami1129#ins_link_time} would not be automatically updated when {Harami1129#link_time} changes from the existing value and manual intervention is demanded (n.b., {HaramiVidMusicAssoc#created_at} differs from {#HaramiVid#updated_at} expectedly.)
  # (4) after processing:
  #     (1) update +event_item_id+; not creating new EventItem (maybe in the future, depending on the place?)
  #     (2) you may create a new ArtistMusicPlay, depending on the combination of Artist/Music
  #     (3) +event_item_id+ would not be updated in the subsequent downloading.  It is set only at the first population.
  #         Users are free to update the column, though.
  #
  # == Columns
  #
  # * release_date : Release Date of the video
  # * created_at : As usual
  # * updated_at : As usual except it is not *touched* if only the change is last_downloaded_at
  # * last_downloaded_at : Timestamp when downloading happened the last time, which may have or not altered columns
  # * orig_modified_at : Timestamp when the downloaded data differ from the existing ones, in which case this is identical to last_downloaded_at (until another downloading happens); n.b., even if the change is insignificant (such as, trailing spaces), this is updated.
  # * ins_at : Timestamp when (internal) insertion to the ins_* columns in the same row/record happens; n.b., if the newly downloaded data are not *significantly* different from the existing ones (for example, extra spaces do not count), no new insertion is performed.
  # * checked_at : Timestamp when manual check by someone is performed; n.b., this may follow updates in orig_modified_at if the last change in the downloaded data is insignificant (e.g., trailing spaces) and the check is already up to date.
  #
  # Basically, when checked_at is earlier than orig_modified_at, caution for the row/record should be prompted to Harami editors.
  #
  # == Internal-insersion and populating to other tables.
  #
  # Note that which columns are to be updated is automatically judged in {#fill_ins_column!}
  #
  # This method assumes {#updated_col_syms} is set (unless new),
  # which should be done by {#fill_ins_column!}.
  #
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {Harami1229#different_columns_at_destination} for the returned value is set.
  # @return [self]
  def insert_populate(messages: [], dryrun: false)
    fill_ins_column! # sets @updated_col_syms

    populate_ins_cols_default(messages: messages, dryrun: dryrun)
    self
  end

  # Dryrun {#insert_populate} and returns a Hash to point Array of each Models
  #
  # Returned models are invalid if they are to be newly created. They are valid
  # if they have already existed before this method is run, in which case {#changed?}
  # in the returned model may be true.
  #
  # Different from {#insert_populate} with (+dryrun: true+) in the sense actual DB insertion
  # is performed in this method. The +dryrun+ option in this method is always ignored.
  #
  # Returns a Hash of Array of models like {:Artist => [artist1, artist2, ...]}.
  # In reality, all the Array elements should have only 1 model (Translation may have 2 in the future, if the algorithm changes).
  #
  # Note that no association works between the returned models, because they do not
  # exist on the DB anymore.  For example, for the returned Hash of Array +hsary+,
  #   hsary[:Music].translations+   # => an empty Relation.
  #   hsary[:Translation].find{|i| i.translatable_type == "Music"}        # => Music model
  #   hsary[:Translation].find{|i| i.translatable_type == "Music"}.music  # => nil
  #
  # Alternative algorithm that works only when all the linked models are created with this method.
  #
  #   ActiveRecord::Base.descendants.select{|i| !i.abstract_class? && !i.name.include?('::')}.each do |model|  # Exclusion of "::" is needed to filter out schema_migrations etc.
  #     mdls = model.where('updated_at > ?', t_before)
  #     allmodels.push mdls.to_a.sort{|a,b| a.created_at <=> b.created_at} if !mdls.empty?
  #   end
  #
  # @param allow_null_engage: [Boolean] if true (Def), it is possible either or both of Engage and HaramiVidMusicAssoc do not exist.
  # @return [Hash<Symbol => Array<ApplicationRecord>>] Symbol is Model name like :EventGroup
  def insert_populate_true_dryrun(messages: [], allow_null_engage: true, dryrun: nil)
    # Returns a propagated Translation from Harami1129. If there are multiple ones, the English one has a priority.
    # @return [Translation, NilClass]
    def model_trans_same_title(model)
      model.translations.where(title: ins_title).order(Arel.sql("CASE WHEN #{model.class.table_name}.langcode = 'en' THEN 0 ELSE 1 END")).first
    end

    reths = {self.class.name.to_sym => [self]} # Hash of Arrays
    begin
      Rails.application.eager_load!
      ActiveRecord::Base.transaction(requires_new: true) do
        t_before = DateTime.now
        insert_populate(messages: messages, dryrun: false)
        raise "Harami1129#harami_vid is nil: #{self.inspect}" if !harami_vid
        hv = harami_vid
        reths[hv.class.name.to_sym] = [hv.reload]
        reths[:Translation] = hv.translations.where(title: ins_title).order(:created_at).to_a.map{|em| em.reload}

        raise(ActiveRecord::Rollback, "Force rollback.") if not_music

        ar_where = [(ins_link_time ? "timing IS NULL OR " : "")+"timing = ?", ins_link_time]
        assoc_musics = hv.harami_vid_music_assocs.where(*ar_where)
        if !ins_song.blank?
          reths[:HaramiVidMusicAssoc] = assoc_musics.to_a.map{|em| em.reload}  # Append [HaramiVidMusicAssoc]
        end

        if !(engage)
          raise "Engage does not exist: #{self.inspect}" if !allow_null_engage
          raise "Engage does not exist despite existences of ins_singer and ins_artist: #{self.inspect}" if !ins_song.blank? && !ins_singer.blank?
          raise ActiveRecord::Rollback, "Force rollback."
        end

        if !assoc_musics.first.music == engage.music
          raise "Musics in harami_vid_music_assocs (#{assoc_musics.to_a.inspect}) is inconsistent with engage.music (#{engage.music.inspect})."
        end

        reths[engage.class.name.to_sym] = [engage.reload]
        reths[:Music ] = [engage.music.reload]
        reths[:Artist] = [engage.artist.reload]

        # Pick up the consistent Translation with Harami1129 only.
        reths[:Translation] += engage.music.translations.where( title: ins_song  ).order(:created_at).to_a.map{|em| em.reload}
        reths[:Translation] += engage.artist.translations.where(title: ins_singer).order(:created_at).to_a.map{|em| em.reload}

        raise ActiveRecord::Rollback, "Force rollback."
      end
    end

    #allmodels.each do |em|
    #  reths[em.first.class.name.to_sym] = em
    #end
    reths
  end

  # Wrapper of {#populate_ins_cols} so the columns to update
  # are automatically determined.
  #
  # This can be directly called from {Harami1129s::PopulatesController}
  # to re-populate data.
  #
  # @param message: [Array<String>] intent(out) for error/information messages.
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {Harami1229#different_columns_at_destination} for the returned value is set.
  def populate_ins_cols_default(messages: [], dryrun: false, force: false)
    # In practice it is unlikely self is new_record? because fill_ins_column!
    # should have "save"-d it, unless the record is not downloaded but
    # is manually generated (but not saved yet) in which ins_* have been
    # assigned.
    updates =
      if (new_record? || !harami_vid)
        ALL_INS_COLS
      else
        self.updated_col_syms = get_upd_hash(ignore_ins_at: true, force: force).keys
        updated_col_syms.select{|i| ALL_INS_COLS.include? i}
      end
    populate_ins_cols(updates: updates, messages: messages, dryrun: dryrun)
  end

  # Fill blank ins_* columns, from the downloaded columns
  #
  # {ModerateHarami1129sController#index} (maybe {Harami1129sController#index}?) shows an index table,
  # in which the rows that have different +title+ and +ins_title+ and yet
  # have +checked_at+ earlier than +orig_modified_at+ are clearly marked
  # so that a moderator can have a look at.
  #
  # {ModerateHarami1129sController#new} is redirected to
  # {HaramiVidController#new} (which is a user interface to add
  # an existing video) with a certain set of initial parameters passed in GET, which
  # includes a hidden parameter of +harami1129_id`
  # In automatic processing, it should be directed to {EditHaramiVidController#create}
  #
  # {ModerateHarami1129sController#edit} (and +show+) shows a row of {Harami1129}
  # along with the corresponding DB columns, highlighting where a difference lies.
  # A moderator can select which of the (newly) downloaded and existing DB column
  # is correct for each column. Also the moderator is given a link to directly
  # edit the destination DB table cell (in case neither is correct).
  #
  # As for the artist (singer) and music (song), two types of choices should be
  # given when the existing record is wrong: whether the spelling or entity is wrong.
  # If the latter, if the downloaded artist (singer) exists, the existing artist
  # is given as a choice or if not, a creation option is given; only one of them
  # is provided as an option, in addition to spelling correction. If the registered
  # artist in the DB table is a wrong person but the newly downloaded singer (artist)
  # has mis-spelling (hence creation option alone is provided), then s/he should
  # just jump to the {HaramiVid} editing panel to correct it.
  #
  # The submission by moderators is handled by {ModerateHarami1129sController#update} as usual.
  # Once the moderator has confirmed all the inconsistent columns, +checked_at+
  # in {Harami1129} table is updated.
  # Note +checked_at+ means human intervention time only.
  #
  # The method {Harami1129#inject_one_to_tables} performs injection (population) of
  # the data in {Harami1129} to other DB tables.  It is called by
  # {MassInjectFromHarami1129AutoController} or {ModerateHarami1129sController#update}.
  # The method decides whether the record in the existing DB tables should be craeted/updated etc,
  # along with +force+ option.
  #  It accepts options indicating which columns are to be updated, either forcibly or not, and whether creation/switch or correction for artist and music.
  #Note a video can contain multiple musics (and 1-to-1 artist, b/c artist can be a group, though technically a music can be engaged by multiple artists!).
  #
  # In conclusion, InternalInsertionsControllers is unnecessary!
  #
  # * {DownloadHarami1129Controllers} simply downloads it.
  # * {ModerateHarami1129sController#index} shows a moderation panel.
  # * {HaramiVidControllers#new} performs a new injection to other DBs.
  # * {ModerateHarami1129sController#edit} shows a moderation editing panel.
  #
  #
  # -----------------
  #
  # 1. some columns are exactly as downloaded,
  # 2. some columns (ins_*) are converted from the corresponding column 1 (downloaded) by {InternalInsertionsController} and are used as seeds to be injected to our DB tables,
  # 3. once the data have been injected to DB tables from the column-set 2 by {InjectFromHarami1129sController}, the set 2 basically remains unchanged even if the column-set 1 alters,
  # 4. exceptions for case 3: (A) null columns in "ins_*" can be updated any time, (B) run {InternalInsertionsController} with +force+ option (manual run by a moderator).
  #
  # For example, suppose column +title+ (as downloaded) was changed
  # after an injection to DB tables. Then, +title+ and +ins_title+ stay
  # different, until manually instructed differently.
  # For manual internal-insertion, a moderator can select which
  # columns are updated.  The control panel must show, (1) downloaded
  # +title+, (2) internally-inserted +ins_title+, and (3) the title
  # (i.e. {Translation#title} of {HaramiVid}). Among these, (2) and (3)
  # are usually the same, though (3) can be independently edited.
  #
  # As another example, suppose (1) column +singer+ (as downloaded) is "Beatles".
  # Then, (2) +ins_singer+ is "Beatles". The injected DB table (i.e. (3) {Translation#title} of {Artist})
  # was initially "Beatles". But an editor corrected the last one as "Beatles, The".
  # Then, (2) and (3) will stay different.
  # Note that in this case, (3) can be tracked via the row's parent ({HaramiVid})) =>
  # {HaramiVidMusicAssoc} => {Music} => {Artist}.
  #
  # Then, suppose the newly downloaded data are updated; (1) column +singer+
  # was modified to "Queen". (2) column +ins_singer+ remain unchanged until
  # a moderator decides to reflect the change forcibly to +ins_singer+.
  # Then, the subsequent injection to DB tables {InjectFromHarami1129sController}
  # should be given choices: whether editing the singer's name or creating
  # (or linking to) a new singer.
  #
  #
  # == Detail
  #
  # The columns {Harami1129} are (apart from a couple of them):
  #
  # The data as downloaded from remote:
  # title (video title; may change at every download), song, singer, release_date.
  # link_root, link_time
  # In addition, every time download is perforemed,
  # +last_downloaded_at+ is set.
  #
  # This method invoked by {InternalInsertionsController} fills or updates
  # the following columns:
  # ins_title, ins_song, ins_singer, ins_release_date, ins_link_root, ins_link_time
  # together with the time +ins_at+, the time when the insertion was performed.
  # These (but ins_at) are the direct seeds to be injected to various tables
  # of this app.
  #
  # Once controller {InjectFromHarami1129sController} performs injection of the data
  # from "ins_*" to various tables like "musics", it sets the foreign key
  # harami_vid_id
  #
  # The first insertion to "ins_*" columns from the initial download of
  # a column in {Harami1129} is straightforward.
  # All "ins_*" columns are filled with no checking.
  # The same goes as long as if either
  #
  # 1. harami_vid_id is NOT set, or
  # 2. not_music is TRUE (which is manually set)
  #
  # Once In subsequent attempts {InjectFromHarami1129s} after a subsequent download,
  # {InternalInsertionsController} can check the consistency between
  # "ins_*" columns and original.
  # the actually injected data (to tables like "musics") and
  # newly downloaded data (like the column "song" and "ins_song")
  # based on, for example, "ins_at" etc.
  #
  #  id                                                    :bigint           not null, primary key
  #  id_remote(Row number of the table on the remote URI)  :bigint
  #  note                                                  :text
  #  created_at                                            :datetime         not null
  #  updated_at                                            :datetime         not null
  #  harami_vid_id                                         :bigint
  # {Harami1129} has the following column which are not exactly the data downloaded:
  #   "ins_at", "id_remote", "last_downloaded_at", "not_music", "harami_vid_id", "note", "created_at", "updated_at"
  #
  # If loaded, ins_at is updated and set to the same time as updated_at .
  #
  # If the original hasn't been updated (or more strictly, nothing
  # has been downloaded, though manual-editing may have been made) since the last
  # insertion of ins_* columns, no attempt of *significant* (but empty) {#update!}
  # is made and nil is returned.
  #
  # This returns {Harami1129}, which is guaranteed to be updated, whether
  # attempted to be saved or simply reloaded (if the condition to update fails);
  # therefore, self.new_record? is always false, except in the cases where
  # the update/save action raises an error and if self is a new record.
  #
  # @param force: [Boolean] if true, last_downloaded_at is ignored (Def: false)
  # @return [TrueClass, NilClass] truthy if *attempted* to be updated. Else nil.
  #   {#updated_at_previously_changed?} would return TRUE if updated. {#ins_at_changed?} means the same in this case.
  #   Note this returns TRUE if one of ins_* is nil AND if the corresponding "from" column too is nil
  #   (providing the time comparison satisfies the condition, else no attempt would be made
  #   in the first place).
  #   Therefore, to check out the update status, you should use  {#updated_at_previously_changed?}
  #   instead of the returned status of this method.
  def fill_ins_column!(force: false)
    self.updated_col_syms = []

    # Get Hash to pass to update!
    upd_data = get_upd_hash(force: force)
    return refresh_changed_and_return_nil if !upd_data

    # There are no ins_* row(s) to update in Harami1129
    if upd_data.empty?
      update_orig_modified_at_checked_at
      return refresh_changed_and_return_nil
    end

    begin
      updated_at_be4 = updated_at
      ret = update!(**upd_data)
      self.updated_col_syms = saved_changes.keys.map(&:to_sym)  # => e.g., {"ins_song"=>[nil, "Love"]}  # Alias of previous_changes (?)
      # Note this (=updated_col_syms) has to be saved here; else the caller will see ins_at be the only column that has changed.

      if updated_at_be4 == updated_at  # Basically, if there were no changes to be saved, leading to update! being not fired.
        return update_orig_modified_at_checked_at || ret
      end

      self.ins_at = updated_at
      # orig_modified_at should have been set at the time of downloading at the same
      # time as last_downloaded at.  Just to play safe.
      self.orig_modified_at = (last_downloaded_at || updated_at) # last_downloaded_at should be never nil.)

      return save!(touch: false)
    rescue
      logger.error "Failed to update the row of the specified id=#{id} in Harami1129: upd_data="+upd_data.inspect
      raise
    end
  end

  # Gets a Hash to be used to update! some ins_* columns
  #
  # @param ignore_ins_at: [Boolean] if specified true (Def: false), ins_at is not checked
  #    Otherwise, ins_at is compared with last_downloaded_at so columns are not
  #    re-populated in default (unless +force+ option is specified).
  # @param foce: [Boolean]
  # @return [Hash<Symbol => Object>, NilClass] nil if no update is needed
  def get_upd_hash(ignore_ins_at: false, force: false)
    # No need to update, because of the time comparison result.
    return nil if !force && !ignore_ins_at && last_downloaded_at && ins_at && last_downloaded_at <= ins_at

    # Gets a "raw" Hash, where blank ins_* are specified to be updated.
    # Hash is like, {:ins_title => "Beatles"}
    # {#preprocess_space_zenkaku} is performed.
    hstmp = prepare_raw_hash_for_fill_ins_column(force: force)

    # Adjust/add not_music, song and note in upd_data
    # e.g., words in a pair of parentheses are removed from the title.
    adjust_update_hash(**hstmp)
  end


  # To update orig_modified_at and maybe checked_at
  #
  # If the downloaded column(s) have changed even if slightly (like spaces
  # are trimmed), we will update orig_modified_at (if not, nil is returned).
  #
  # To what time? If last_downloaded_at is changed but not saved, the current time,
  # or else the same as last_downloaded_at.
  # Note that any unsaved changes are saved now.
  #
  # @return [NilClass, TrueClass] if saved, it returns true
  def update_orig_modified_at_checked_at
    return if !(changed_attribute_names_to_save.any?{|i| ALL_DOWNLOADED_COLS_STR.include? i} ||
                saved_changes.keys.any?{|i| ALL_DOWNLOADED_COLS_STR.include? i})

    time2save = (changed_attribute_names_to_save.include?("last_downloaded_at") ? Time.now : last_downloaded_at)
    self.checked_at = time2save if checked_at && orig_modified_at && orig_modified_at <= checked_at
    self.orig_modified_at = time2save
    save!(touch: false)
  end
  private :update_orig_modified_at_checked_at

  # Internal method to make "empty" save and returns nil
  # so self.updated_at_previously_changed? is refreshed.
  def refresh_changed_and_return_nil
    return nil if new_record?  # If a new record, not save-d.
    reload
    save!(touch: false)
    nil
  end
  private :refresh_changed_and_return_nil

  # Populate ins_* of {Harami1129} to {HaramiVid}, {Music}, {Artist}, {Engage}, {EventItem}
  #
  # as well as {HaramiVidMusicAssoc} and {HaramiVidEventItemAssoc} and {ArtistMusicPlay}
  #
  # @param updates: [Array<Symbol>] Column names (Symbols) like :ins_singer which has been updated/created (and hence they may be reflected in the populated tables).
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {Harami1229#columns_at_destination} for the returned value is set.
  # @return [self, NilClass] nil if dryrun or something goes wrong.
  def populate_ins_cols(updates: [], messages: [], dryrun: false)
    self.columns_at_destination = {be4: {}, aft: {}, tgt: {}.with_indifferent_access, hvma_current: nil}
    begin
      ActiveRecord::Base.transaction(requires_new: true) do
        hvid = harami_vid

        # If Harami1129#engage_id is nil, all related values in columns_for_harami1129[:be4] are nil.
        # NOTE: Even if dryrun, an empty Engage is required to return
        #   in order to pass ret.columns_for_harami1129 to the parent.
        hvid_exists = !!hvid

        hvid ||= HaramiVid.find_one_for_harami1129(self) # maybe new
        if !hvid ############################## Check out when this happens!!
          logger.error "(Harami1129##{__method__}) Found no HaramiVid AND failed to create one. Why? Harami1129=: "+self.inspect
          return nil
        end

        self.columns_at_destination[:tgt][:harami_vid] = hvid
        hvid.set_with_harami1129(self, updates: updates, dryrun: dryrun)  # not saved yet.
        self.columns_at_destination[:be4] = 
          if !hvid_exists || hvid.new_record?
            # If it is a new record, it means nothing is set, yet, obviously!
            hvid.columns_for_harami1129[:be4].map{|k,v| [k, nil]}.to_h
          else
            hvid.columns_for_harami1129[:be4].dup
          end
        self.columns_at_destination[:aft] = hvid.columns_for_harami1129[:aft].dup

        # self.engage_id may neeed to be altered.
        messages = []
        enga = Engage.find_and_set_one_harami1129(self, updates: updates, messages: messages, dryrun: dryrun)
        self.columns_at_destination[:tgt][:engage] = enga
        if enga
          self.columns_at_destination[:tgt][:music]  = enga.music
          self.columns_at_destination[:tgt][:artist] = enga.artist
          %i(ins_singer ins_song).each do |i|
            self.columns_at_destination[:be4][i] = enga.columns_for_harami1129[:be4][i]
            self.columns_at_destination[:aft][i] = enga.columns_for_harami1129[:aft][i]
          end
        end
        #self.columns_at_destination.delete :engage if (enga == engage) # Should never be true...

        hvmas = hvid.harami_vid_music_assocs
        self.columns_at_destination[:be4][:ins_link_time] = 
          if !hvmas || !hvid_exists
            # No HaramiVidMusicAssocs association
            nil
          else
            if ins_link_time && hvmas.where(timing: ins_link_time).exists?
              # If the same time exists in the associated HaramiVidMusicAssocs, use it.
              self.columns_at_destination[:hvma_current] = hvmas.where(timing: ins_link_time).first
              ins_link_time
            elsif !engage.blank? && !engage.music.blank?
              # Or, search based on Music and Artist, providing self#engage_id is non-nil.
              cand = hvmas.where(music: engage.music).first
              self.columns_at_destination[:hvma_current] = hvmas.where(music: engage.music).first
              (cand ? cand.timing : nil)
            else
              nil
            end
          end

        if dryrun
          return
        end

        if engage && (enga != engage)
          engare_prev = engage
          arstr = [enga, engage_prev].map{|i| [(i ? i.music.title : nil), (i ? i.artist.title : nil)].map{|j| j.inspect}.join("/")}
          msg = sprintf("Music/Artist combination has changed from %s into %s.", *(arstr))
          messages << msg
          logger.info msg "(Harami1129: ID=#{id}) "+msg
        end

        hvid.save! if hvid.changed?
        self.harami_vid = hvid
        enga.save! if enga.changed?  # redundant, as it should have been already saved.
        self.engage     = enga

        set_event_item_ref(enga, hvid)
        hvid.set_with_harami1129_event_item_assoc(self, dryrun: dryrun)  # HaramiVid#place may be modified.
        save!

        # If music has changed, the existing {HaramiVidMusicAssoc} is deleted (and replaced).
        destroy_harami_vid_music_assoc(hvid, engare_prev.music) if engare_prev && enga.music != engare_prev.music
        update_harami_vid_music_assoc(hvid, enga.music, ins_link_time, updates: updates)
      end
    rescue
      ## Transaction failed.
      raise
    end
    self
  end

  # Set event_item_id if nil
  #
  # @return [Hash<event_item, artist_music_play, place>] if updated, returns an Array of Models. EventItem can be accessed via +event_item+ anyway.
  def set_event_item_ref(enga, hvid)
    guessed_place = self.class.guess_place(ins_title)  # defined in /app/models/concerns/module_guess_place.rb

    self.event_item = 
      if event_item
        event_item
      elsif (h1129 = self.class.where(ins_link_root: ins_link_root).where.not(event_item_id: nil).first)
        # If there is one with the same URL with a significant EventItem, use it.
        h1129.event_item
      else
        (_find_evit_in_harami_vid(enga, hvid, guessed_place: guessed_place) ||  # takes from HaramiVid (this happens when HaramiVid for the same URI is created before Harami1129)
         create_event_item_ref(hvid.event_items.first, guessed_place: guessed_place)) # create one.
      end

    create_def_amp!(enga, guessed_place: nil)
  end


  # Find an existing most-appropriate EventItem
  #
  # @param enga [Engage]
  # @param hvid [HaramiVid]
  # @param guessed_place: [Place, NilClass]
  # @return [EventItem, NilClass]
  def _find_evit_in_harami_vid(enga, hvid=harami_vid, guessed_place: nil)
    guessed_place ||= self.class.guess_place(ins_title)  # defined in /app/models/concerns/module_guess_place.rb
    hvid.event_items.each do |evit|
      if evit.place == guessed_place && evit.musics.where(id: enga.music.id).exists?
        return evit
      end
    end
    return nil
  end
  private :_find_evit_in_harami_vid


  # Create a default ArtistMusicPlay
  #
  # @param enga [Engage]
  # @param guessed_place: [Place, NilClass]
  # @return [Hash] .with_indifferent_access
  def create_def_amp!(enga, guessed_place: nil)
    guessed_place ||= self.class.guess_place(ins_title)  # defined in /app/models/concerns/module_guess_place.rb
    amp = nil
    if event_item && enga && enga.music && !enga.music.unknown? 
      amp = ArtistMusicPlay.initialize_default_artist(:harami1129, event_item: event_item, music: enga.music)
      amp.save! if amp.new_record?  # should never fail.
    end

    { event_item: event_item,
      artist_music_play: amp,
      place: guessed_place,
    }.with_indifferent_access
  end


  # Create a new event_item to belongs_to
  #
  # @param template [EentItem, NilClass] template if any. Its Event is used.
  # @return [EentItem, NilClass] newly created one; nil if failed.
  def create_event_item_ref(template=nil, guessed_place: nil)
    event = (template ? template.event : nil)
    guessed_place ||= self.class.guess_place(ins_title)  # defined in /app/models/concerns/module_guess_place.rb
    evt_kind =  EventItem.new_default(:harami1129, event: event, place: guessed_place, save_event: false, ref_title: ins_title, date: ins_release_date, place_confidence: :low)  # Either Event or EventItem
    if EventItem == evt_kind.class
      evit = evt_kind
      if evit.save
        return evit.reload
      else
        logger.error("ERROR(#{File.basename __FILE__}:#{__method__}): for some reason, EventItem failed to be saved! EventItem=#{evt_kind.inspect}")
        return
      end
    end

    # evt_kind is an Event (NOT EventItem)
    if evt_kind.save   # Just to play VERY safe (so as not to stop processing with a risk of Harami1129#event_item being nil.
      evt_kind.event_items.reset
      return evt_kind.event_items.first
    else
      logger.error("ERROR(#{File.basename __FILE__}:#{__method__}): for some reason, Event failed to be saved! Event=#{evt_kind.inspect}")
      return
    end
  end

  # Create or maybe update {HaramiVidMusicAssoc}
  #
  # If only the timing has changed (in the record in the remote website),
  # given a {Harami1129} has only one associated music, the timing of
  # the existing {HaramiVidMusicAssoc} should be updated (instead of
  # a new {HaramiVidMusicAssoc} with a different timing from the existing one
  # being created).
  #
  # @param harami_vid [HaramiVid]
  # @param music [music]
  # @param timing [timing]
  # @param updates: [Array<Symbol>] Column names (Symbols) like :ins_singer which has been updated/created (and hence they may be reflected in the populated tables).
  # @return [NilClass]
  def update_harami_vid_music_assoc(harami_vid, music, timing, updates: [])
    self.columns_at_destination[:be4][:ins_link_time] = nil
    self.columns_at_destination[:tgt][:harami_vid_music_assoc] = nil

    return if !updates.include?(:ins_song) && !updates.include?(:ins_link_time) || !music
    self.columns_at_destination[:be4][:ins_link_time] = timing
    self.columns_at_destination[:aft][:ins_link_time] = timing
    return if HaramiVidMusicAssoc.find_by(harami_vid: harami_vid, music: music, timing: timing) # exact one already exists.

    existings = HaramiVidMusicAssoc.where(harami_vid: harami_vid, music: music)
    n_counts = existings.count
    if n_counts != 1
      # If there is none (or confusingly, more than one), a new association is created.
      self.columns_at_destination[:be4][:ins_link_time] = nil
      assoc = HaramiVidMusicAssoc.create!(harami_vid: harami_vid, music: music, timing: timing)
      self.columns_at_destination[:tgt][:harami_vid_music_assoc] = assoc 
      logger.warn "More than one HaramiVidMusicAssoc for the same Music and HaramiVid are found, which should not happen (ID=#{assoc.id} is further added now): #{existings.inspect}" if n_counts > 1
      return
    end

    return if !updates.include?(:ins_link_time)

    # "timing" of the existing association is updated.
    self.columns_at_destination[:hvma_current] = hvma = existings.first
    self.columns_at_destination[:be4][:ins_link_time] = hvma.timing
    existings.first.update!(timing: timing)
    return
  end

  # Destroy (potentially all, though there should be only 1) {HaramiVidMusicAssoc} for {HaramiVid} && {Music}
  #
  # @param harami_vid [HaramiVid]
  # @param music [music]
  # @return [NilClass]
  def destroy_harami_vid_music_assoc(harami_vid, music)
    existings = HaramiVidMusicAssoc.where(harami_vid: harami_vid, music: music)
    n_counts = existings.count
    return if n_counts < 1
    if n_counts == 1
      existings.first.destroy
      return
    end

    logger.warn "More than one HaramiVidMusicAssoc for the same Music and HaramiVid are found, which should not happen. All are destroyed now: #{existings.inspect}"
    existings.each do |i|
      i.destroy
    end
  end

  # Adjust not_music, song and note in Hash to {#update!}
  #
  # Many entries of the "singer" 'ハラミちゃん' contain non-musics.
  # Some music titles contain a memo in parentheses, which is
  # recorded in "note".
  #
  # Music title examples:
  #
  # * Honesty（トラブルにより途中から） → Honesty
  # * Honesty（トラブルにより途中まで） → Honesty
  # * さくら（独唱） : 曲名!
  # * Ballade pour Adeline（渚のアデリーヌ） → The Japanese word transferred to note
  #
  # @param row [Harami1129]
  # @param **upd_data [Hash] to pass to {#update!}
  # @return [Hash] modified (adjusted) upd_data
  def adjust_update_hash(**upd_data)
    hsret = {}.merge upd_data
    if preprocess_space_zenkaku(singer) == 'ハラミちゃん' # preprocess_.. is redundant (though not heavy) as preprocessed in prepare_raw_hash_for_fill_ins_column()
      if !not_music.nil? && !harami_song_is_music?(song)
        # For 'ハラミちゃん' entries,
        # if not_music is nil (aka has not been explicitly set) AND if it is judged
        # to be for music, set the flag (to be used to update!) to be true.
        hsret[:not_music] = true
      end
    end

    k_singer = ins_column_key(:singer)
    k_song   = ins_column_key(:song)
    hsret[k_singer] = preprocess_space_zenkaku(hsret[k_singer]) if hsret[k_singer] # preprocess.. is redundant
    case hsret[k_singer]
    when /(.+)(featuring.+)/i
      hsret[k_singer] = preprocess_space_zenkaku($1) # preprocess.. is redundant
      hsret[:note] = appended_note(hsret[:note], $2)
    when 'キロロ'
      hsret[k_singer] = 'Kiroro'
    end

    if hsret[k_song]
      hsret[k_song] = preprocess_space_zenkaku(hsret[k_song]) # preprocess.. is redundant
      hsret[k_song].strip!
      if !hsret[k_song].blank?
        case hsret[k_song]
        when /\Aさくら\s*\(\s*独唱\s*\)\z/
          hsret[k_song] = "さくら(独唱)"
        when 'ベストフレンド'
          if hsret[k_singer] == 'Kiroro'
            hsret[k_song] = 'Best Friend'
          end
        when /\A(\P{OpenPunctuation}+)(\p{OpenPunctuation}.*)/
          hsret[k_song], to_add = $1.strip, $2+'.'
          hsret[:note] = appended_note(note, to_add)
        else
          # Do nothing
        end
      end
    end

    hsret
  end

  # True if the entry ("by" Harami) is for music.
  #
  # * セブンイレブンの入店音アレンジ
  # * ファミリーマートの入店音アレンジ
  # * マクドナルド ポテトの揚がる音＋広瀬香美さんのゲレンデが溶けるほど恋したいアレンジ
  # * happy birthday, happy birthday to you
  # * ハラミ体操
  # * ハラミ体操（バラードバージョン）
  # * ハラミ体操と筋肉体操
  # * ファンファーレ
  def harami_song_is_music?(songtxt)
    rege = /(?:入店音|揚がる音).*アレンジ|ハラミ体操|\bhappy\s+birthday\b|ファンファーレ|\bfanfare\b/i
    !!(rege =~ preprocess_space_zenkaku(songtxt))
  end

  # Returns Hash of Time-related columns with the ordered number
  #
  # created_at is ignored.
  #
  # @example The hash keys are naturally ordered in this order regardless of "order" elements.
  #   time_attrs_with_order
  #    # => {updated_at: {value: TimeC, order: 6}
  #    #     last_downloaded_at: {value: TimeB, order: 4},
  #    #     orig_modified_at:   {value: TimeB, order: 4},
  #    #     ins_at:     {value: TimeA, order: 3},
  #    #     created_at:     {value: TimeA, order: 2},
  #    #     checked_at: {value: nil, order: 1},}
  #
  # @return [Hash]
  def time_attrs_with_order
    references = DEF_TIME_COLUMN_ORDERS.map(&:to_s)
    hs = slice(*(%i(created_at checked_at ins_at orig_modified_at last_downloaded_at updated_at)))
    numbers = number_ordered_keys(hs)
    hs.map{|k,v| [k, {value: v, order: numbers[k]}]}.sort{|a,b|
      cmp = (b[1][:order] <=> a[1][:order])
      next cmp if cmp != 0
      (references.find_index{|ib| ib == b[0].to_s} || Float::INFINITY) <=>
      (references.find_index{|ia| ia == a[0].to_s} || Float::INFINITY)  # Reverse order re time!
    }.to_h
  end


  # Returns the best {Translation} String for the language of Singer/Song
  #
  # @param modelname [String, Symbol] either "artist" or "music"
  # @return [String, NilClass] nil only if self.engage_id is nil
  def find_populated_best_trans_str_of_lang(modelname)
    modelname = modelname.to_s
    raise "Contact the code developer" if !(%w(artist music).include?(modelname))

    ins_colname = self.class.model2harami1129_colname(modelname, ins: true)  # Either "ins_singer" or "ins_song"
    langcode = guess_lang_code(send(ins_colname)) # defined in ModuleCommon
    return nil if !engage

    engage.send(modelname).title_or_alt(langcode: langcode, lang_fallback_option: :both)
  end

  protected

    # Prepare a Hash to fill the columns ins_*
    #
    # @param force: [Boolean] if true, all ins_* are forcibly updated.
    # @return [Hash]
    #   e.g., {'ins_singer' => 'Beatles', 'ins_link_time' => 5678}
    def prepare_raw_hash_for_fill_ins_column(force: false)
      all_cols = Harami1129.column_names

      ## Column names (String) of all ins_*, e.g., ins_title, ins_singer, etc.
      ## Note: ins_at is contained in this but has no corresponding column in remote_cols
      #all_ins_cols = all_cols.select{|i| Harami1129::RE_PREFIX_INSERTED_WITHIN.match i}

      # Build hash (String<String>) like: 'ins_link_root' => 'link_root'
      # For those that exist in DB as both a column for remote and ins_*
      mapping_from_ins_remote = ALL_INS_COLS.map{|i| j=self.class.downloaded_column_key(i).to_s; (all_cols.include?(j) ? [i, j] : nil)}.compact.to_h  # id_remote is not included

      # Creates like: 'ins_singer' => 'Beatles', 'ins_link_time' => 5678
      upd_data = {}
      # n_updated = 0
      mapping_from_ins_remote.each_pair do |ea_ins, ea_remote|
        upd_data[ea_ins.to_sym] = preprocess_space_zenkaku(self.send(ea_remote)) if force || self.send(ea_ins).blank?
      end

      upd_data[:ins_link_root] = ApplicationHelper.uri_youtube(upd_data[:ins_link_root]) if upd_data[:ins_link_root]

      ### WARNING: This should be removed (unneccesary).
      %i(ins_singer ins_song).each do |kwd|
        upd_data[kwd] = definite_article_to_tail upd_data[kwd] if upd_data[kwd]
      end

      # If not_music is nil AND if singer exists, not_music is set false.
      # Otherwise, it remains as it is; i.e., non-existence of singer
      # would not automatically set not_music=true.
      upd_data[:not_music] = false if self.not_music.nil? && !any_zenkaku_to_ascii(song || "").strip.blank?

      upd_data
    end

    # Appended string to replace upd_data[:note] with, respecting the existing record, avoiding duplication.
    #
    # @param instr [String, NilClass] Original string
    # @param str_to_append_raw [String] String to append
    # @return [String] Updated
    def appended_note(instr, str_to_append_raw)
      instr = any_zenkaku_to_ascii(instr || "").strip # note it is NOT processed by {#preprocess_space_zenkaku}
      str_to_append = preprocess_space_zenkaku(str_to_append_raw, **(COMMON_DEF_SLIM_OPTIONS.merge({convert_spaces: false}))) # newlines are preserved

      return instr if instr.include? str_to_append  # Avoid duplication

      instr << ' ' if !instr.blank?
      instr << str_to_append
    end

  private
    def at_least_one_entry
      if %i(singer song title link_root ins_singer ins_song ins_title ins_link_root).all?{ |i|
           send(i).blank?
         }
        errors.add :base, "Null entry is invalid."
      end
    end
end
