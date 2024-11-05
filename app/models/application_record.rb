# coding: utf-8

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  extend ModuleApplicationBase

  # The default logger_title
  LOGGER_TITLE_FMT = "(ID=%s: %s%s)"

  # String representation of the Model for the previous page,
  # to which the website should be redirected to after an action like create.
  attr_accessor :prev_model_name 

  # ID of the Model corresponding to {#prev_model_name}
  attr_accessor :prev_model_id

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
end

class << ApplicationRecord
  # If this is set true, {EventGroup.destroy_all}, {Event.destroy_all} {EventItem.destroy_all} are allowed.
  # Default: false.
  attr_accessor :allow_destroy_all
end
ApplicationRecord.allow_destroy_all = false

require "reverse_sql_order"   # A user monkey patch to modify reverse_sql_order() in ActiveRecord::QueryMethods::WhereChain
