# coding: utf-8

class Musics::AcTitlesController < BaseAutoCompleteTitlesController
  skip_before_action :authenticate_user!, :only => [:index]  # Revert application_controller.rb so Index is accessible by anyone.

  # This constant should be defined in each sub-class of BaseAutoCompleteTitlesController (and BaseMergesController)
  MODEL_SYM = :music

  #def index
  #  super
  #end
end
