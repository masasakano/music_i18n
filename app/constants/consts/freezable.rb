module Consts
  module Freezable
    # Freezes every constant's value defined in this module and Module itself.
    def freeze_all
      constants(false).each do |const_name|  # false means "not inheriting"
        value = const_get(const_name)
        value.freeze if value.respond_to?(:freeze)
      end

      freeze
    end
  end
end

