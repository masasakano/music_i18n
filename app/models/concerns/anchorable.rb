module Anchorable
  extend ActiveSupport::Concern
  included do
    has_many :anchorings, as: :anchorable, dependent: :destroy
    has_many :urls, through: :anchorings

    #after_create :create_anchor
  end

  ## When a Music/Event etc is created, this creates Anchoring automatically, providing an existing URL is specified in Form.
  #def create_anchor
  #  Anchoring.create(anchorable_type: self.class.name, anchorable_id: self.id, url_id: self.form_url_id) if self.form_url_id.present?
  #end

  # Creates a Url (maybe also Domain and DomainTitle and related Translations) and adds its association (Anchoring) to self
  #
  # Most parameters can be added automatically after intelligently guessed,
  # because some of them are mandatory at the Url model level.
  #
  # @note
  #   The caller may put the call to this method in a DB transaction because this method saves records in DB.
  #
  # @param urlstr [String] of URL/URI
  # @param **kwds [Hash] For the other options, see {Url.create_url_from_str}
  # @return [Anchoring] its id is nil if faling in saving, where errors should be set and its url_id may be nil (though there is a very small chance Url/Domain/DomainTitle may have been created, but somehow saving Anchoring failed)
  def create_assign_url(urlstr, **kwds)
    url = Url.create_url_from_str(urlstr, **kwds)
    add_url(url)
  end

  # Adds an association (Anchoaring) of Url to self
  #
  # @note
  #   The caller may put the call to this method in a DB transaction because this method saves a new Anchoring in DB.
  #
  # @param url [Url]
  # @return [Anchoring] its id is nil if faling in saving, where errors should be set.
  def add_url(url, **kwds)
    ret = Anchoring.create(anchorable_type: self.class.name, anchorable_id: self.id, url_id: url.id)

    # Transfers error messages, if any, to the returning Object. Note ret may have already its errors set.
    if url.errors.any?
      url.errors.full_messages.each do |emsg|
        ret.errors.add :base, emsg
      end
    end

    self.anchorings.reset
    ret
  end
end

