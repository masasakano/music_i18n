# -*- coding: utf-8 -*-

# Common module to implement wiki_url and fetch_h1_wiki attributes and after_action callback for :create/:update for Controller
#
# include this module if you want Url to be imported on create.
# Although the after_action callback defined in this module is called also
# after :update, this method does nothing as long as @record.wiki_url is blank?
#
# @example Controller
#   include ModuleWikiUrl  # for wiki_url fetch_h1_wiki methods
#   MAIN_FORM_KEYS ||= []
#   MAIN_FORM_KEYS.concat(%w(weight note) + ["start_time(1i)", "start_time(2i)", "start_time(3i)"])
#   MAIN_FORM_BOOL_KEYS ||= []  # if necessary
#   def create
#     @record = @artist = Artist.new(@hsmain)  # make sure to define @record as the main target to save.
#     ...
#   end
#   def update
#     @record = @artist
#     ...
#   end
#
# == NOTE
#
module ModuleWikiUrl
  extend ActiveSupport::Concern  # to activate class methods, after_action etc
  #include ApplicationHelper

  MODULE_WIKI_URL_ATTRIBUTES = %w(wiki_url fetch_h1_wiki)

  included do
    if const_defined?(:MAIN_FORM_KEYS)  # used in set_hsparams_main in application_controller.rb
      MODULE_WIKI_URL_ATTRIBUTES.each do |eatt|
        const_get(:MAIN_FORM_KEYS).push eatt
      end
    else
      const_set(:MAIN_FORM_KEYS, attrs2add)
    end

    if const_defined?(:MAIN_FORM_BOOL_KEYS)  # used in set_hsparams_main in application_controller.rb
      const_get(:MAIN_FORM_BOOL_KEYS).push :fetch_h1_wiki
    else
      const_set(:MAIN_FORM_BOOL_KEYS, [:fetch_h1_wiki])
    end
      

    after_action :add_wiki_url, only: [:create, :update]  # Views likely do not provide the option in :edit (hence :update)
  end

  #module ClassMethods
  #end

  # after_save callback to create a new Anchoring (likely Url, potentially Domain/DomainTitle) for a Wikipedia link
  #
  # Here, the problematic input for wiki_url would not interfere with the other processings.
  # If the main processing (save) succeeds, any failure in saving (creating) an Anchor would not stop it, except for flash messaging.
  # If the main processing fails, the wiki_url entry the user has input should remain because @record.wiki_url unchanges.
  #
  def add_wiki_url
    if !@record
      msg = "@record is undefined in Controller #{self.class.name}, so wiki_url cannot be processed."
      msg_warn = "ERROR(#{File.basename __FILE__}:#{__method__}) "+msg 
      warn         msg_warn
      logger.error msg_warn
      add_flash_message(:warning, msg)  # defined in application_controller.rb
      return
    elsif @record.new_record? || @record.wiki_url.blank?
      return
    end

    #url = Url.find_or_create_url_from_wikipedia_str(@record.wiki_url, anchorable: @record, assess_host_part: true, fetch_h1: convert_param_bool(@record.fetch_h1_wiki))  # convert_param_bool defined in application_controller.rb
    url = Url.find_or_create_url_from_wikipedia_str(@record.wiki_url, anchorable: @record, assess_host_part: true, fetch_h1: @record.fetch_h1_wiki)  # convert_param_bool defined in application_controller.rb
    if !url
      add_flash_message(:alert, "Input Wikipedia URL seems invalid: "+@record.wiki_url.strip)  # defined in application_controller.rb
      return
    end
      
    if (url_created=url.was_created?)
      if url.domain_created?
        add_flash_message(:notice, "new Domain record created: "+url.domain.domain)
      end
      add_flash_message(:notice, "new Url record created: "+url.url)
    end

    anc = Anchoring.find_or_initialize_by(anchorable: @record, url: url)
    if !anc.new_record?
      add_flash_message(:notice, "Anchoring already exists for URL=<#{url}>. No change.")
      return
    end

    msg = sprintf(" for URL=<#{url}>")
    if anc.save
      add_flash_message(:notice, sprintf("Successfully created Anchoring (pID=\d)", anc.id)+msg)
    else
      add_flash_message(:alert, sprintf("Failed to create Anchoring%s. Errors: %s", msg, anc.errors.messages.inspect))
    end
  end

  #### NOTE: Here, this tries to raise a warning if the "model" for the Controller defines necessary methods, but this is not easily possible from a Controller class, let alone Module like this file!
  ##
  ## Checks if the Model is cosistent to support this feature, and maybe issues a warning when this module is included.
  #if !ModuleWikiUrl::MODULE_WIKI_URL_ATTRIBUTES.all?{|eatt| self.respond_to?(eatt) }
  #  warn "WARNING: a Model that includes (#{self.name}) does not define attr_accessor for #{ModuleWikiUrl::MODULE_WIKI_URL_ATTRIBUTES.map(&:to_sym).inspect}"
  #end

  #################
  private 
  #################

end

