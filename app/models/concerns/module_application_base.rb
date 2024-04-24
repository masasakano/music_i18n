# -*- coding: utf-8 -*-

# Common module to extend {ApplicationRecord}
#
module ModuleApplicationBase
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
  # @example In case you need to overwrite it (see also the bottom section of BaseWithTranslation).
  #    class << Post
  #      alias_method :create_basic_application!, :create_basic! if !self.method_defined?(:create_basic_application!)
  #      def create_basic!(*args, error_message: "", another: nil, **kwds)
  #        # NOTE: "another" must be specified as an optional argument with a Symbol key unlike
  #        #   Rails' default, where it can be specified either with a String key or as a Hash in the main argument.
  #        create_basic_application!(*args, error_message: "You must give a mandatory unique 'mname'", another: (another || 5), **kwds)
  #      end
  #    end
  #
  #    record = Post.create_basic!  # => Exception (for this class)
  #    record = Post.create_basic!(mname: rand(0.2).to_s)  # => ok
  #
  # @return [ApplicationRecord]
  def create_basic!(*args, error_message: "", **kwds)
    begin
      create!(*args, **kwds)
    rescue
      warn "ERROR(#{__method__}): "+error_message if error_message.present?
      raise
    end
  end
end

