# -*- coding: utf-8 -*-

# Common module to extend {ApplicationRecord}
#
module ModuleApplicationBase
  # Default maximum trial number to search for a unique text
  MAX_UNIQUE_NUMBER = 100000

  # Wrapper of {ApplicationRecord.create!}
  #
  # To extend ApplicationRecord.create!
  # Meant to be used for testing.
  #
  # Note that this method as often modified in child classes often creates
  # other model instances.  For example, {Artist.create_basic!} in default
  # creates a new {Sex}, which is a mandatory parameter, unless you explicitly
  # specify a sex in {#create_basic!}.
  #
  # @example In case you need to overwrite it (see also the bottom section of BaseWithTranslation for a slightly more advanced example).
  #    class << Post
  #      alias_method :create_basic_application!, :create_basic! if !self.method_defined?(:create_basic_application!)
  #      def create_basic!(*args, error_message: "", another: nil, **kwds)
  #        # NOTE: In this example, "another" must be specified as an optional argument with a Symbol key unlike
  #        #   Rails' default, where it can be specified either with a String key or as a Hash in the main argument.
  #        create_basic_application!(*args, error_message: "You must give a mandatory unique 'mname'", another: (another || 5), **kwds)
  #      end
  #    end
  #
  #    record = Post.create_basic!  # => Exception (for this class)
  #    record = Post.create_basic!(mname: rand(0.2).to_s)  # => ok
  #
  # @return [ApplicationRecord]
  def create_basic!(*args, error_message: "", **kwds, &blok)
    begin
      create!(*args, **kwds, &blok)
    rescue
      warn "ERROR(#{__method__}): "+error_message if error_message.present?
      raise
    end
  end

  #alias :initialize_basic :initialize
  # a simple alias of the original in practice. Just to define it.
  def initialize_basic(*args, error_message: "", **kwds, &blok)
    begin
      new(*args, **kwds, &blok)
    rescue
      warn "ERROR(#{__method__}): "+error_message if error_message.present?
      raise
    end
  end

  # Returns a unique string within a context
  #
  # A number may be added between prefix and separator + postfix if it is already unique.
  # A separator becomes blank if postfix is blank.
  #
  # @example simple (in the context of an EventItem class method)
  #   EventItem.get_unique_string(:machine_title, prefix: "item", postfix: "MyGroup", separator: "", separator2: "_")
  #     # => item_MyGroup"
  #     # => item1_MyGroup"
  #     # => item2_MyGroup"
  #
  # @example joins
  #   Channel.get_unique_string("translations.title", rela: Channel.joins(:translations), prefix: "channel", separator: "-")
  #     # => channel"
  #     # => channel-1"
  #     # => channel-2"
  #
  # @param col [String, Symbol] DB column name
  # @param rela: [ActiveRecord::Relation] Def: self
  # @param prefix: [String]
  # @param postfix: [String]
  # @param separator: [String] For the former separator between prefix and number.
  # @param separator2: [String] For the latter separator between the number and postfix. If nil, separator is used.
  # @return [String] unique String
  def get_unique_string(col, rela: self, prefix: "unique", postfix: "", separator: "-", separator2: nil)
    postfix ||= ""
    separator2 ||= separator
    separator2 = "" if postfix.blank?
    trial = prefix + separator2 + postfix
    return trial if !rela.where(col => trial).exists?

    (1..MAX_UNIQUE_NUMBER).each do |suffix|
      trial = prefix + separator + suffix.to_s + separator2 + postfix
      return trial if !rela.where(col => trial).exists?
    end
    raise "(#{File.basename __FILE__}:#{self.name}.#{__method__}) Suffix exceeded the limit for prefix=#{prefix.inspect} and postfix=#{(separator+postfix).inspect}. Contact the code developer."
  end

end

