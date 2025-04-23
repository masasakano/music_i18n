class Artists::AnchoringsController < BaseAnchorablesController

  # Essential constant used in the parent class BaseAnchorablesController
  ANCHORABLE_CLASS = Artist

  #### The following defined in BaseAnchorablesController
  # skip_before_action :authenticate_user!, only: [:index, :show]
  # before_action :set_anchoring, except: [:index, :new, :create]
  # before_action :set_new_anchoring, only:       [:new, :create]
  # before_action :auth_for!    , except: [:index, :new, :create, :show]

  ### Main methods are all defined in parent BaseAnchorablesController
  # Standard CRUD: index, new, show, edit, create, update, destroy

  private

end
