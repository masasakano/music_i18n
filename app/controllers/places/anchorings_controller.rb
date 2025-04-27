class Places::AnchoringsController < BaseAnchorablesController
  # Essential constant used in the parent class BaseAnchorablesController
  ANCHORABLE_CLASS = self.name.split(":").first.singularize.constantize # Place class
end

