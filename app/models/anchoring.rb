# == Schema Information
#
# Table name: anchorings
#
#  id              :bigint           not null, primary key
#  anchorable_type :string           not null
#  note            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  anchorable_id   :bigint           not null
#  url_id          :bigint           not null
#
# Indexes
#
#  index_anchorings_on_anchorable  (anchorable_type,anchorable_id)
#  index_anchorings_on_url_id      (url_id)
#  index_url_anchorables           (url_id,anchorable_type,anchorable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (url_id => urls.id) ON DELETE => cascade
#
class Anchoring < ApplicationRecord
  include ModuleCommon # for transfer_errors

  include ModuleWasFound # defines attr_writers @was_found, @was_created and their questioned-readers. (8 methods)
  define_was_found_for("url")          # defined in ModuleWasFound; defines url_found? etc. (8 methods)
  define_was_found_for("domain")       # defined in ModuleWasFound; defines domain_found? etc. (8 methods)
  define_was_found_for("domain_title") # defined in ModuleWasFound; defines domain_title_found? etc. (8 methods)

  belongs_to :url
  belongs_to :anchorable, polymorphic: true

  has_one :domain,        through: :url
  has_one :domain_title,  through: :url
  has_one :site_category, through: :url

  validate :unique_within_anchorable

  attr_accessor :notice_messages

  # :note only
  NATIVE_ATTRIBUTES = %i(note)

  # Attributees of {Url} to br (possibly) used for the Anchoring form
  URL_ATTRIBUTES = %i(url_langcode weight domain_id published_date last_confirmed_date memo_editor)

  # Form keys that are not the attributes of Url, nor the original method of Anchoring (== :note)
  # fetch_h1 is a checkbox to load H1 from the remote URL to initialize or update the title
  NATIVE_FORM_ACCESSORS = %i(site_category_id title langcode is_orig fetch_h1 url_form)

  # Required methods for the sake of forms. Except for those in {NATIVE_FORM_ACCESSORS} and
  # {NATIVE_ATTRIBUTES}, they are from the parent Url (= {URL_ATTRIBUTES}).
  FORM_ACCESSORS = NATIVE_ATTRIBUTES + URL_ATTRIBUTES + NATIVE_FORM_ACCESSORS

  # attr_accessor for forms 
  (NATIVE_FORM_ACCESSORS + URL_ATTRIBUTES).each do |metho|
    attr_accessor metho
  end

  # Models to show counts in task task_find_or_create_multi_from_note
  MODELS_TO_COUNT_IN_MIGRATION = [Translation, DomainTitle, Domain, Url, Anchoring]

  # URL in String (never nil) prefixed with a scheme (typically "https://"), used during form-processing.
  attr_accessor :http_url

  def site_category_label
    site_category.title_or_alt(prefer_shorter: true, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "(UNDEFINED)") if site_category.present?
  end

  # Wrapper of {Anchoring.find_or_create_multi_from_note}, called from Rake task of DB migration
  #
  # @param verbose [Boolean] true in default (from Rake task). Migration calls this with (verbose: false
  # @return [Hash] {Translation: 2, Url: 2, Anchoring: 3} etc - increments in records
  def self.task_find_or_create_multi_from_note(anchorable, id_anchorable=nil, verbose: true, **opts, &bl)
    models = MODELS_TO_COUNT_IN_MIGRATION
    anchorable = Url.send(:_get_anchorable_from_arg, anchorable, id_anchorable)
    printf "Anchorable: %s(pID=%d): %s\n", anchorable.class.name, anchorable.id, (anchorable.respond_to?(:title_or_alt_for_selection) ? anchorable.title_or_alt_for_selection.inspect : "")
    note_is_blank = (note=anchorable.note).blank?
    msg_be4 = sprintf("  note(before): %s\n", (note_is_blank ? "[:blank:]" : note.inspect))
    print msg_be4 if verbose
    return ModuleCommon.model_counts(*models, set_at: 0) if note_is_blank

    is_found_one = false
    ActiveRecord::Base.transaction(requires_new: true) do
      # Inside a Transasction so that the counts of the models are accurate
      counts_be4 = ModuleCommon.model_counts(*models)  # defiend in ModuleCommon
      find_or_create_multi_from_note(anchorable, id_anchorable, **opts, &bl).each_with_index do |anc, i_th|
        is_found_one = true
        print msg_be4 if !verbose  # At least one Anchoring is being processed.
        if anc.blank?
          puts "WARNING: Blank Anchorable... skipped." 
          next
        end
        begin
          errmsg = " : ERROR(Anchoring): " + anc.errors.messages.inspect if anc.errors.any?
          printf("%d(%s): %s : Url(%s:%s: %s)-Anchoring(%s:%s)%s%s\n",
                 i_th+1, (anc.errors.any? ? "FAIL!" : "ok"),
                 anc.url.original_path,
                 (anc.url.id || "nil"), (anc.was_created? && anc.url_found? ? "found" : "created"), 
                 anc.url.title_or_alt_for_selection.inspect,
                 (anc.id || "nil"),     (anc.was_found? ? "found" : "created"), 
                 (anc.was_created? && anc.domain_created? ? " (Domain created)" : ""),
                 errmsg )
        rescue HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError => er
          puts "WARNING: <InconsistencyInWasFoundError> for Anchoring(#{anc.id})"
        end
      end

      printf("  note(after):  %s\n", anchorable.note.inspect) if (is_found_one || verbose)
      ModuleCommon.model_count_diffs(counts_be4, ModuleCommon.model_counts(*models))  # defiend in ModuleCommon
    end
  end

  # Find or create Anchorings (and maybe Urls, even Domains/DomainTitles) for anchorable#note, optionally removing the URL-Stgings in the note
  #
  # If the same-ISH URL-Strings appear in the note, only the last one is (optionally) removed.
  # Accordingly, the order of the returned Array of Urls is *reversed* from the URL-like Strings
  # in the note.
  #
  # Internally this may create Url-s and maybe even Domain/DomainTitle-s.
  #
  # @example
  #    Anchoring.find_or_create_multi_from_note(Place.last)
  #      # => e.g., [Anchoring, ...]
  #      #    # Anchoring.url.original_path == "www.example.com" (for example!)
  #
  # @example  No particular processing for Wikipedia or Harmai-Chronicle URLs
  #    Anchoring.find_or_create_multi_from_note(Place.last){|valid_path, orig_path| true }
  #
  # @param anchorable [ActiveRecord, String] anchorable one, or its anchorable_type (namely its class name)
  # @param id_anchorable [Integer, String, NilClass] pID of anchorable. mandatory when anchorable is anchorable_type.
  # @param remove_from_note: [Boolean] If true, not only (potentially creating Urls, anchorable#note is updated with the URL-string parts removed
  # @param fetch_h1: [Boolean] If true, fetches the title from the remote URL on create.
  # @return [Array<Anchoring>]
  def self.find_or_create_multi_from_note(anchorable, id_anchorable=nil, remove_from_note: false, **opts, &bl)
    urls = Url.send(__method__, anchorable, id_anchorable, **opts, &bl)  # private class method of Url

    arret = urls.map{ |url|
      next nil if url.blank?  # playing safe.
      anchoring = anchorable.anchorings.find_by(url_id: url.id)&.tap(&:set_was_found_true)&.tap(&:set_url_found_true)&.tap(&:set_domain_found_true)
      anchoring ||= Anchoring.new(url_id: url.id)&.tap(&:set_was_created_true)
      anchoring.url = url  # reassign the same Url instance so anchoring.url has some values defined, like #original_path and #was_found? (i.e., anchoring.url.was_found?)
      next anchoring if anchoring.was_found?  # == !new_record?

      # Now, Anchoring must be created (saved) with a Url on DB (which may have been just created).
      # url_id may be nil (if Url's creation failed and Url remained new_record?)
      anchoring.set_url_found_if_true(url.was_found?)
      anchoring.set_domain_found_if_true(url.domain_found?)

      if url.new_record?
        anchoring.transfer_errors(url, prefix: "[Url] ", mappings: {url_langcode: :url_langcode, site_category: :site_category, note: :base})
      else
        anchorable.anchorings << anchoring
      end
      anchoring.transfer_errors_from_parents
      anchoring  # possibly new_record?. Possibly errors.any? is true (from Anchoring#save or inherited from Url)
    }

    remove_all_url_strs_from_note( arret ) if remove_from_note

    arret  # of Anchorings, any of which may have errors. Also, anchorable may have errors.
  end

  # @param anchorable [ActiveRecord, String] anchorable one, or its anchorable_type (namely its class name)
  # @param id_anchorable [Integer, String, NilClass] pID of anchorable. mandatory when anchorable is anchorable_type.
  # @param bang: [Boolean] if true, save! is used.
  # @return [Array<Anchoring>] Array of Anchoring of the exported Url-s (NOT(!) an Array of Urls)
  def self.export_urls_to_note(anchorable, id_anchorable=nil, bang: false)
    anchorable = Url.send(:_get_anchorable_from_arg, anchorable, id_anchorable)  # private class method of Url
    urls = Url.find_multi_from_note(anchorable)

    ret_ancs = []
    anchorable.note ||= ""
    anchorable.anchorings.each do |anc|
      next if urls.include? anc.url
      ret_ancs << anc
      anchorable.note << " "+Addressable::URI.unencode(anc.url.url)
    end

    anchorable.send(bang ? :save! : :save) if !ret_ancs.empty?
    ret_ancs
  end

  # Wrapper routine to remove all URL-like Strings from an anchoarable#note
  #
  # @param anchorings [Array<Anchoring>]  All Anchoring-s are assumed to point to a common anchorable.
  # @return void
  def self.remove_all_url_strs_from_note(anchorings)
    anchorings.each do |anc|
      next if !anc || anc.new_record? || !anc.url  # Anchoring should have been saved; if not, it means saving failed for some reason, and then String should not be removed from note.
      anchorable ||= anc.anchorable
      status = anc.url.remove_str_from_note(anchorable)  # assuming anchoring.url.original_path is defined; any Url processed here should have it defined.
      if !status
        anc.notice_messages ||= []
        anc.notice_messages << ( msg = "ERROR(#{__method__}): saving #{anchorable.class.name}#note somehow failed: String-to-remove=(#{anc.url.original_path.inspect}) from Note=#{anchorable.note.inspect} of anchorable="+anchorable.inspect )
        Rails.logger.error msg
      end
    end
  end

  def transfer_errors_from_parents
    mappings = {url: :url_form,
                note: :base, is_orig: :base, langcode: :base, weight: :base}
                  # url_langcode: :url_langcode, site_category_id: :site_category_id,  # taken care of by default
    if anchorable && anchorable.errors.any?
      transfer_errors(anchorable, prefix: "[#{anchorable.class.name}] ", mappings: mappings)  # defined in ModuleCommon
    end
    if url && url.errors.any?
      transfer_errors(url, prefix: "[Url] ", mappings: mappings)  # defined in ModuleCommon
    end
  end

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)
  # Modifying {#inspect}
  def inspect
    inspect_orig.sub(/(, url_id: (\d+)),/){
      url_str = "nil"
      if (u=Url.find($2)) && (u.url.present?)
        (url_str = Addressable::URI.unencode(u.url)) rescue nil
      end
      sprintf("%s(%s),", $1, url_str)
    }
  end

  private

    # Validating the uniqueness of Anchoring within an anchorable
    def unique_within_anchorable
      if anchorable.anchorings.where(url_id: url_id).where.not(id: id).exists?
        errors.add :url_form, url.url+" is already registered for this record."
      end
    end


end
