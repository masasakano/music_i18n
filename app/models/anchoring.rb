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
  belongs_to :url
  belongs_to :anchorable, polymorphic: true

  has_one :domain,        through: :url
  has_one :domain_title,  through: :url
  has_one :site_category, through: :url

  validate :unique_within_anchorable

  # methods for the sake of forms. Except for title, langcode, url_form, and they are from the parent Url.
  FORM_ACCESSORS = %i(site_category_id title langcode is_orig url_form url_langcode weight domain_id published_date last_confirmed_date memo_editor)

  # attr_accessor for forms 
  FORM_ACCESSORS.each do |metho|
    attr_accessor metho
  end

  attr_accessor :site_category_id  # purely for forms.  The association does not define this method, hence no conflict.
  ## Below does not work well!  Anyway, it seems SimpleForm takes care of +site_category_id+
  ## such that it would load the existing {self#site_category} to +site_category_id+
  ## so the simple attr_accessor works best!
  #def site_category_id
  #  site_category ? site_category.id : nil
  #end
  #attr_writer :site_category_id

  def site_category_label
    site_category.title_or_alt(prefer_shorter: true, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "(UNDEFINED)") if site_category.present?
  end


  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)

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
