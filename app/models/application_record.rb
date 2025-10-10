# coding: utf-8

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  DEF_UTF8_COLLATION = "und-x-icu"

  # PostgreSQL collation name for the locale (key)
  #
  # e.g., "C" => "C.UTF-8", "en_GB" => "en_GB.UTF-8" (on macOS/BSD), "C.utf8" (on Linux), "invalid" => "C"
  @@cached_utf8collations = {
    libc: {
      C:   {}.with_indifferent_access,  # (redundant) initialization, the value of which is set in self.utf8collation()
    }.with_indifferent_access,
    icu: {  #  (International Components for Unicode)
      C:   DEF_UTF8_COLLATION,  # Defined for convenience. Technically, this should be nil b/c it does not exist.
      und: DEF_UTF8_COLLATION,  # (undetermined) the most generic one
      en: {
        und: "en-x-icu",
        GB:  "en-GB-x-icu",
        US:  "en-US-x-icu",  # `en-US-u-va-posix-x-icu` etc
      }.with_indifferent_access,
      ja: "ja-x-icu",
      ko: "ko-x-icu",
      fr: "fr-x-icu",
      de: "de-x-icu",
    }.with_indifferent_access
  }.with_indifferent_access

  extend ModuleApplicationBase

  # The default logger_title
  LOGGER_TITLE_FMT = "(ID=%s: %s%s)"

  # String representation of the Model for the previous page,
  # to which the website should be redirected to after an action like create.
  attr_accessor :prev_model_name 

  # ID of the Model corresponding to {#prev_model_name}
  attr_accessor :prev_model_id

  # Checks if a specific collation name exists in the PostgreSQL catalog.
  def self.collation_available?(collation_name)
    return true if %w(C POSIX).include?(collation_name.upcase)

    1 == connection.select_value("SELECT 1 FROM pg_collation WHERE collname = '#{connection.quote_string(collation_name)}'")
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    false
  end

  # Wrapper of {ApplicationRecord.utf8collation}
  #
  # You can specify the locale like "en_GB" as it is.
  #
  # @example
  #    ApplicationRecord.utf8collation_for()
  #      # => "und-x-icu"   # DEF_UTF8_COLLATION
  #    ApplicationRecord.utf8collation_for("en_GB")
  #      # => "en-GB-x-icu"
  #    ApplicationRecord.utf8collation_for("en_GB", provider: "libc")
  #      # => "en_GB.UTF-8"  # (if macOS)
  #
  # @param loc [String, NilClass] locale, e.g., "en_GB". If ommitted, "und" (undetermined) if provider=="icu", else "C".
  # @para provider: [String, Symbol, NilClass] Either "icu" or "libc"
  #    For lang of "und", this has to be +:icu+
  # @return [String] like "en_GB.UTF-8"
  def self.utf8collation_for(loc=nil, provider: nil)
    lang, dialect = [nil, nil]
    lang, dialect = loc.split("_") if loc
    utf8collation(lang, provider: provider, dialect: dialect)
  end

  # Returns (maybe cached) default PostgreSQL UTF-8 collation, depending on the platform
  #
  # See the wrapper {ApplicationRecord.utf8collation_for}
  #
  # @para lang [String, Symbol, NilClass] "und" (undetermined) in Default, or "C" is default if provider=="libc".
  # @para provider: [String, Symbol, NilClass] Either "icu" or "libc"
  #    For lang of "und", this has to be +:icu+
  # @para dialect: [String, Symbol, NilClass] :und (undetermined (for naming here)), "US", "GB", etc if any
  #    For lang of "C", this has to be +:und+
  # @return [String] guaranteed to be a valid String. e.g., "und-x-icu" or "C.UTF-8"
  def self.utf8collation(lang=nil, provider: nil, dialect: nil)
    provider ||= "icu"
    provider = provider.to_s
    dialect ||= :und
    dialect   = dialect.to_s
    lang    ||= ((provider == "icu") ? "und" : "C")
    lang = lang.to_s
    case provider
    when "icu"
      if @@cached_utf8collations[:icu].has_key?(lang)
        return @@cached_utf8collations[:icu][lang] if !@@cached_utf8collations[:icu][lang].respond_to?(:has_key?)
        cand = @@cached_utf8collations[:icu][lang][dialect]
        return cand if cand.present?
        msg = sprintf("WARNING: Unexpected language-dialect combination (%s_%s) specified for method(%s) in %s  Returning the default value.", lang, dialect, __method__, __FILE__)
        warn msg+" See log for the backtrace."
        logger.warn msg+" Backtrace: \n"+caller.join("\n")
        return send(__method__, lang, provider: provider)
      else
        msg = sprintf("WARNING: Unexpected language (%s) specified for method(%s) in %s  Returning the default value.", lang, __method__, __FILE__)
        warn msg+" See log for the backtrace."
        logger.warn msg+" Backtrace: \n"+caller.join("\n")
        return send(__method__)
      end
    when "libc"
      raise ArgumentError, "'und' unacceptable for 'libc': Parameters: "+[lang, provider, dialect].inspect if "und" == lang.downcase
      raise ArgumentError, "dialect makes no sense for lang='C': Parameters: "+[lang, provider, dialect].inspect if "C" == lang && "und" != dialect.downcase

      @@cached_utf8collations[:libc][lang] = {}.with_indifferent_access if !@@cached_utf8collations[:libc].has_key?(lang)

      lang_dia = lang
      lang_dia += (("und" == dialect.downcase) ? "" : "_" + dialect)

      return @@cached_utf8collations[:libc][lang][dialect] if @@cached_utf8collations[:libc][lang][dialect]

      begin
        collation_name = lang_dia +
          case RUBY_PLATFORM
          when /linux/i
            ".utf8"
          # when /darwin/i  # Maybe "bsd", too?
          #   ".UTF-8"
          else  # This should be the standard convention.
            ".UTF-8"
          end

        @@cached_utf8collations[:libc][lang][dialect] = 
          if collation_available?(collation_name)
            collation_name
          else
            if "und" == dialect
              if "C" == lang
                msg = sprintf("WARNING: Collation-name is unavailable on this platform (%s in %s).  Returning 'C' instead.", collation_name, __method__, __FILE__)
                warn msg+" See log for the backtrace."
                logger.warn msg+" Backtrace: \n"+caller.join("\n")
                "C"
              else
                send(__method__, "C", provider: provider, dialect: :und)
              end
            else
              send(__method__, lang, provider: provider, dialect: :und)
            end
          end
      rescue => err
        # Above is not tested, hence this blanket rescue.
        logger.error "ERROR: unexpected error caught in method (#{__method__}): #{err.class.name}: #{err.message}  Backtrace: \n"+caller.join("\n")
        return "C"
      end
    else
      raise ArgumentError, "Parameters: "+[lang, provider, dialect].inspect
    end
  end # self.utf8collation()

  # String to output for a logger output to explain the model
  #
  # @example simplest
  #    Music.last.logger_title
  #      # => '(ID=123: "Light, The")'
  #
  # @example with a fmt
  #    se=Sex[9]; se.logger_title(fmt: se.class::LOGGER_TITLE_FMT.sub(/^\(([^)]+)\)$/, '[\1]'))
  #      # => '[ID=9: "not applicable"]'
  #
  # @example with extra
  #    se=Sex[9]; se.logger_title(extra: [" / ISO=#{se.iso5218}"])
  #      # => '(ID=9: "not applicable" / ISO=9)'
  #
  # @example with a different method
  #    Sex[1].logger_title(method: :alt_title)
  #      # => '(ID=1: "M")'
  #
  # @example with a block
  #    se=Sex[9]; se.logger_title(){ |method, extra, fmt|
  #      sprintf fmt, se.id.inspect,
  #                   se.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true).inspect,
  #                   " [#{se.iso5218} : #{se.updated_at}]"
  #    }
  #      # => '(ID=9: "適用不能" [9 : Wed, 25 Aug 2021 01:04:22.123456789 UTC +00:00])'
  #
  # @see logger_titles (plural) in module_application_base.rb
  #
  # @param method: [Symbol, String, NilClass] If nil, automatically set one of %i(mname name title machine_title inspect)
  # @param extra: [Array<String>] Extra String to pass to the format. Default (sprintf) format has one extra "%s", so one element is mandatory unless you specify your own fmt.
  # @param fmt: [String] Format for sprintf.
  # @return [String]
  # @yield [Symbol, Array<String>, String] The (determined or specified) method, the "extra" Array of String-s, and (sprintf) format are given as arguments. Should return the exact String this method would return.
  def logger_title(method: nil, extra: [""], fmt: LOGGER_TITLE_FMT)
    if method.nil?
      method = %i(mname name title machine_title).find{|metho| respond_to?(metho)}
    end

    if block_given?
      yield(method, extra, fmt)
    else
      sprintf fmt, id.inspect, (method ? send(method) : self).inspect, *extra
    end
  end

  # Log an info message after create
  #
  # Core routine of {ApplicationController#logger_after_create}
  #
  # @param model [ApplicationRecord]
  # @param extra_str: [String] see {ApplicationController#logger_after_create}
  # @param execute_class: [Class, String] usually a subclass of {ApplicationController} (though the default here is inevitably ActiveRecord...)
  # @param method_txt: [String] pass +__message__+
  # @param header_txt: [String] Def: "Created"
  # @param user: [User] if specified, user information is also left in the returned message (for Logger)
  # @return [void]
  def logger_after_create(model=self, extra_str: "", execute_class: self.class, method_txt: "create", header_txt: "Created", user: nil)
    execute_class_str = (execute_class.respond_to?(:name) ? execute_class.name : execute_class.to_s)
    user_info_str = (user ? " by User-ID="+(Rails.env.test? ? user.display_name.inspect : user.id.to_s) : "")
    logger.info "INFO: #{execute_class_str}##{method_txt}#{user_info_str}: #{header_txt} #{model.class.name} #{model.logger_title(extra: [extra_str])}"
  end

  # Returns true if the record has been destroyed on the DB.
  def db_destroyed?
    !self.class.exists? id
  end

  # copies ActiveRecord#errors from another ActiveRecord to self
  #
  # @param model [ActiveRecord]
  # @param form_attr: [Symbol, String] form name (Def: :base)
  # @param msg2prefix: [String] form name
  def copy_errors_from(model, form_attr: :base, msg2prefix: ": ")
    model.errors.full_messages.each do |msg|  # implicitly including model.errors.any?
      errors.add form_attr, ": Existing #{model.class.name} is not found, yet failed to create a new one: "+msg
    end
  end

  # Temporarily setting Rails-app config value ina block
  #
  # @example
  #   ApplicationRecord.with_config(Rails.application.config.i18n, "fallbacks", [:fr]) do
  #     # ...
  #   end
  #
  # @note
  #   Rails' system, middleware, etc may load the config file at boot
  #   and may never look up it again.  For example, the value of
  #   +config.action_dispatch.show_exceptions+ is read only once, apparently.
  #
  # @param config_object [Object] like +Rails.application.config.i18n+
  # @param setting_name [String] e.g., "fallbacks"
  # @param temp_value [Object] e.g., +[:fr]+
  def self.with_config(config_object, setting_name, temp_value)
    orig_value = config_object.public_send(setting_name)

    begin
      # Use the public accessor method for the best practice.
      # NOTE: config_object.instance_variable_set('@' + setting_name, temp_value) would be thread-unsafe.
      config_object.public_send("#{setting_name}=", temp_value)

      yield
    ensure
      config_object.public_send("#{setting_name}=", orig_value)
    end
  end
end

class << ApplicationRecord
  # If this is set true, {EventGroup.destroy_all}, {Event.destroy_all} {EventItem.destroy_all} are allowed.
  # Default: false.
  attr_accessor :allow_destroy_all
end
ApplicationRecord.allow_destroy_all = false

require "reverse_sql_order"   # A user monkey patch to modify reverse_sql_order() in ActiveRecord::QueryMethods::WhereChain
