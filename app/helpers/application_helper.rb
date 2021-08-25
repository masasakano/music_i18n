module ApplicationHelper

  # For toastr Gem. From
  # <https://stackoverflow.com/a/58778188/3577922>
  def toastr_flash
    flash.each_with_object([]) do |(type, message), flash_messages|
      type = 'success' if type == 'notice'
      type = 'error' if type == 'alert'
      text = "<script>toastr.#{type}('#{message}', '', { closeButton: true, progressBar: true })</script>"
      flash_messages << text.html_safe if message
    end.join("\n").html_safe
  end

  # Returns <title> for HTML from Path
  #
  # This assumes the langcode is 2-characters and no Models are 2-character long.
  #
  # @return [String]
  def get_html_head_title
    ar = url_for.split('/')
    ar = ar.map{|i| i.blank? ? nil : i}.compact
    if (ar.size < 1)
      ''
    else
      langcode_str = ''
      if ar[0].size == 2
        langcode_str = ' ('+ar[0].upcase+')'
        ar.shift
      end
      ar.map{|i| (/^\d*$/ =~ i) ? nil : i}.compact.join('-').capitalize + langcode_str
    end
  end

  # Returns an HTML YouTube link
  #
  # @param word [String, NilClass, Symbol] Hilighted word (for users to click).
  #    If nil, returns a null string.
  #    If the special symbol :uri, the raw URI. Otherwise it must be String.
  # @param root_kwd [String, NilClass] if nil, word is used. This can be omitted.
  # @param timing [Integer, NilClass] in second
  # @param long: [Boolean] if false (Def), youtu.be, else www.youtube.com
  # @return [String] HTML of <a> for YouTube link
  def link_to_youtube(word, root_kwd=nil, timing=nil, long: false)
    return '' if word.blank?
    word = ((word == :uri) ? nil : word.to_s)
    root_kwd ||= word if word
    root_kwd = word if root_kwd.respond_to?(:divmod) && !timing && word
    uri = self.method(:link_to_youtube).owner.uri_youtube(root_kwd, timing, long: long, with_http: true) # <= ApplicationHelper.uri_youtube()
    word = sprintf("%s", uri) if !word
    ActionController::Base.helpers.link_to word, uri 
  end

  # Returns a YouTube URI with/without the preceeding "https//"
  #
  # @param root_kwd [String]
  # @option timing [Integer, NilClass] in second
  # @param long: [Boolean] if false (Def), youtu.be, else www.youtube.com
  # @param with_http: [Boolean] if true (Def: false), returned string contains "https://"
  # @return [String] youtu.be/Wfwe3f8 etc
  def self.uri_youtube(root_kwd, timing=nil, long: false, with_http: false)
    raise "(#{__method__}) nil is not allowed for root_kwd" if !root_kwd
    timing   = nil if timing == "" || timing == "0" || timing == 0
    domain = (long ? 'www.youtube.com' : 'youtu.be')
    root_kwd = root_kwd.sub(%r@\A(?:https?://)?(?:www\.)?(?:(?:youtube.com|youtu.be)/*)?@i, "")
    if /[[:space:]]/ =~ root_kwd
      raise "root_kwd=#{root_kwd.inspect} must contain no spaces."
    end
    timing_part = (timing ? sprintf("?t=%ds", timing) : '')
    (with_http ? "https://" : "") + domain + "/" + root_kwd + timing_part
  end

  # to check whether a record has any dependent children
  #
  # @see https://stackoverflow.com/a/68129947/3577922
  #
  def has_children?
    ## This would be simpler though may initiate more SQL calls:
    #  self.class.reflect_on_all_associations.map{ |a| self.send(a.name).any? }.any?
    self.class.reflect_on_all_associations.each{ |a| return true if self.send(a.name).any? }
    false
  end


  # to check whether a record has any dependent children that
  # would not be cascade-destroyed.
  #
  # @see has_children?
  # @see undestroyable_associations
  #
  # @param skip_nullify: [Boolean] if true (Def), "dependent: :nullify"
  #   will be treated the same as ":destroy", namely they are not counted as "undestroyable".
  def has_undestroyable_children?(**kwd)
    undestroyable_associations(**kwd).each{ |a| return true if self.send(a.name).any? }
    false
  end

  # Returns all undestroyable children
  #
  # @see undestroyable_associations
  #
  # @return [Array<ApplicationRecord>]
  def undestroyable_children(**kwd)
    undestroyable_associations(**kwd).map{ |a| self.send(a.name) }.flatten
    false
  end

  # Returns an Array of associations that may contain dependent children that
  # would not be cascade-destroyed.
  #
  # For example, a user alywas has a role, the association record of which
  # would be destroyed as soon as the user is removed from the DB.
  # That is normal and needs no caution.
  # By contrast, if a user owns an article that would not be cascade-destroyed,
  # deleting of the user must be treated with caution.
  #
  # This method returns the associations that fall into the latter.
  #
  # @see has_undestroyable_children?
  #
  # @param skip_nullify: [Boolean] if true (Def), "dependent: :nullify"
  #   will be treated the same as ":destroy", namely they are not counted as "undestroyable".
  # @return [Array<ActiveRecord::Reflection>]
  def undestroyable_associations(skip_nullify: true)
    destroy_keys = %i(destroy delete destroy_async)
    destroy_keys.push(:nullify) if skip_nullify 
    # Note: the other potentials: [:restrict_with_exception, :restrict_with_error]

    self.class.reflect_on_all_associations.filter{|i|
      opts = i.options
      (!(opts.has_key?(:through) && opts[:through]) &&
       !(opts.has_key?(:dependent) && destroy_keys.include?(opts[:dependent])))
    }
  end
  private :undestroyable_associations


  # Returns either Date or DateTime from Rails form parameters.
  #
  # params obtained from form.date_select contains something like:
  #   "r_date(1i)"=>"2019", "r_date(2i)"=>"1", "r_date(3i)"=>"9"
  #
  # This method converts them to Date or DateTime.
  # In default, Date is returned if the number is 3 or less,
  # unless klass option is given.
  #
  # @param prm [ActionController::Parameters]
  # @param kwd [String] Keyword of params
  # @param klass [Class, NilClass] Date or DateTime, or if nil, it is judged
  #    from the number of the parameters
  # @return [Date, DateTime, NilClass] if none of them is found, nil is returned
  def get_date_time_from_params(prm, kwd, klass=nil)
    num = prm.keys.select{|i| /\A#{Regexp.quote(kwd)}\(\d+i\)\z/ =~ i}.size
    return nil if num == 0
    klass ||= ((num <= 3) ? Date : DateTime)
    begin
      klass.send(:new, *((1..num).to_a.map{|i| prm[sprintf "#{kwd.to_s}(%di)", i].to_i}))
    rescue Date::Error
      warn "Wrong Date format: "+(1..num).to_a.map{|i| prm[sprintf "#{kwd.to_s}(%di)", i].to_i}.inspect
      raise
    end
  end

  # Returns a Boolean value from params value
  #
  # The input should be String.
  #
  # @param prmval [String, NilClass] params['is_ok']
  # @return [Boolean, NilClass]
  def get_bool_from_params(prmval)
    case prmval
    when "", nil  # This should not be the case if params()
      nil
    when "0", 0, "false"
      false
    when "1", 1, "true"
      true
    else
      raise "Unexpected params value=(#{prmval})."
    end
  end

  # Get place from params
  #
  # @param hsprm [Hash, Params]
  # @return [Place]
  def get_place_from_params(hsprm)
    return Place.find(hsprm['place_id'].to_i) if !hsprm['place_id'].blank?

    prm = hsprm['place.prefecture_id']
    return Place.unknown(prefecture: Prefecture.find(prm.to_i)) if !prm.blank?

    prm = hsprm['place.prefecture_id.country_id']
    return Place.unknown(country: Country.find(prm.to_i)) if !prm.blank?

    Place.unknown
  end

  # Get an Artist from Title (or maybe ID)
  #
  # Permitted formats:
  #
  # (1) Beatles, The
  # (2) The Beatles
  # (3) ?567            # for artist.id==567
  # (4) Dummy (ID=568)  # for artist.id==568
  #
  # In (4), the String part of "Dummy" is ignored.
  #
  # @param artist_name [String] Maybe Integer-String like "56" to mean Artist primary ID
  # @param model [Model] to add errors
  # @param langcode: [String] To help identify an Artist
  # @param place: [Place] To help identify an Artist (NOT yet supported!)
  # @return [Artist, NilClass] nil if not found or specified
  def get_artist_from_params(artist_name, model, langcode: nil, place: nil)
    return nil if artist_name.blank?
    artist = 
      case artist_name.strip
      when /\A\?(\d+)\z/, /\(ID=(\d+)\)|\?(\d+)\z/i
        Artist.find ($1 || $2).to_i
      else
        opts = {match_method_upto: :optional_article_ilike} # See Translation::MATCH_METHODS for the other options
        opts.merge!({langcode: langcode})
        Artist.find_by_a_title :titles, artist_name, **opts
      end
    if !artist
      model.errors.add :artist, 'is not registered. Please register the artist first.'
    end
    artist
  end

  # @return [String] Language switcher link used in application.html.erb, "html_safe"-ed.
  def language_switcher_link
    locale_cur = (I18n.locale.blank? ? 'en' : I18n.locale)

    locale_links = %w(en ja).map{ |elc|
      # Maybe replaced with: I18n.available_locales
      lc2display = BaseWithTranslation::LANGUAGE_TITLES[elc.to_sym][elc]
      if locale_cur.to_s == elc
        lc2display
      else
        link_to lc2display, url_for(locale: elc)  # Rails.application.routes.url_helpers.
      end
    }
    ("["+locale_links.join("|")+"]").html_safe
  end

  # to suppress warning, mainly that in Ruby-2.7.0:
  #   "Passing the keyword argument as the last hash parameter is deprecated"
  #
  # Especially, the one raised here:
  #   "/active_record/persistence.rb:630: warning: The called method `update!' is defined here"
  def suppress_ruby270_warnings
    begin
      tmp = $stderr
      $stderr = open('/dev/null', 'w')
      yield
    ensure
      $stderr.close if !$stderr.closed?
      $stderr = (tmp ? tmp : STDERR)
    end
  end
end
