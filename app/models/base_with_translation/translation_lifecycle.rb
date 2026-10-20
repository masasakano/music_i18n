class BaseWithTranslation < ApplicationRecord
  module TranslationLifecycle
    extend ActiveSupport::Concern

    included do
      before_validation :assign_auto_kinds, on: :create
      before_validation :sync_orig_locale, on: :create
      validate :validate_is_orig_consistency
    end

    # On :create, for any {Translation} with kind.blank?:
    #
    # - The first {Translation} in each langcode group receives KIND_FULL.
    #   - If prioritized_translations is given, the Translation would get the highest priority.
    # - Any subsequent {Translation} in that langcode group receives KIND_ALT.
    #
    # @example When several Translations are given in-memory on :create, the specified one(s) will get kind="full" if none of siblings have kind="full".
    #   assign_auto_kinds([{langcode: "ja", title: "何か"}, {langcode: "en", title: "Something"}])
    #
    # @param prioritized_translations [Hash<langcode: String>] e.g., +{en: "abc", ja: "あいう"}+
    def assign_auto_kinds(prioritized_translations = nil)
      priorities = prioritized_translations&.transform_keys { |k| k.to_s.strip }

      active_translations.group_by(&:langcode).each do |lang, group|
        sorted_group = group

        if priorities && (pt_title = priorities[lang.to_s.strip].to_s.strip.presence)
          sorted_group = group.sort_by { |etra| (etra.title.to_s.strip == pt_title) ? 0 : 1 }
        end

        has_full = sorted_group.any? { |t| t.kind == Translation::KIND_FULL }

        sorted_group.each do |tra|
          next unless tra.kind.blank?

          if has_full
            tra.kind = Translation::KIND_ALT
          else
            has_full = true
            tra.kind = Translation::KIND_FULL
          end
        end
      end
    end

    private

    # On :create, sets orig_locale on the parent:
    #
    # - Set to nil if all active translations have is_orig.nil?
    # - Set to the langcode of the translation where is_orig == true
    def sync_orig_locale
      tras = active_translations
      return if tras.empty?

      if tras.all? { |t| t.is_orig.nil? }
        self.orig_locale = nil
      elsif (orig_tra=tras.find { |t| t.is_orig == true })
        self.orig_locale = orig_tra.langcode
      end
    end

    # Validates is_orig sibling consistency:
    # 1. All siblings have is_orig: nil, OR
    # 2. Exactly one sibling has is_orig: true AND all other siblings have is_orig: false.
    def validate_is_orig_consistency
      tras = active_translations
      return if tras.empty?

      orig_flags = tras.map(&:is_orig)

      all_nil = orig_flags.all?(&:nil?)
      exactly_one_true_and_rest_false = (
        orig_flags.count(true) == 1 &&
        orig_flags.count(false) == (tras.size - 1)
      )

      return if all_nil || exactly_one_true_and_rest_false

      errors.add(:base, "is_orig of Translation-s are invalid: either all must be nil, or exactly one must be 'Yes' and all others 'No'.")

      # Attaches errors to individual Translation records so SimpleForm highlights the fields
      tras.each do |tra|
        tra.errors.add(:is_orig, "inconsistent across sibling Translations (must be all nil, or exactly one 'Yes' with all others 'No')")
      end
    end
  end # module TranslationLifecycle
end
