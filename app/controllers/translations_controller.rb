# coding: utf-8
class TranslationsController < ApplicationController
  include ModuleGridController # for set_grid

  before_action :set_translation, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource except: [:new, :create]

  # GET /translations
  # GET /translations.json
  def index
    @translations = Translation.all.order(:translatable_type, :translatable_id)
    @hsuser = User.all.pluck(:id, :display_name).to_h.map{|k,v| [k, ((v.length < 17) ? v : sprintf("%s…%d",v[0..16],k))]}.to_h

    set_grid(Translation, hs_def: {order: :updated_at, descending: true})  # setting @grid; defined in concerns/module_grid_controller.rb
  end

  # GET /translations/1
  # GET /translations/1.json
  def show
  end

  # GET /translations/new
  def new
    hsparam = stripped_params(params.permit(:translatable_id, :translatable_type, :langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji, :is_orig, :weight, :note)) # stripped_params defiend in Parent

    @translation = Translation.new(**hsparam)
    authorize! :create, @translation
  end

  # GET /translations/1/edit
  def edit
  end

  # POST /translations
  # POST /translations.json
  def create
    hsparam = stripped_params(translation_params) # stripped_params defiend in Parent
    hsparam = convert_params_bool(hsparam, :is_orig)  # is_orig can be nil, e.g., a general noun like car/voiture
    @translation = Translation.new hsparam
    authorize! __method__, @translation

    # @translation = Translation.new(translation_params)
    if @translation.langcode.present? && 2 == @translation.langcode.size
      begin
        I18nData.languages(@translation.langcode.upcase)
      rescue I18nData::NoTranslationAvailable
        flash[:warning] ||= []
        flash[:warning] << "The specified locale #{@translation.langcode} looks invalid."
      end
    end

    respond_to do |format|
      if _set_save_translatable
        format.html { redirect_to @translatable, success: message_successfully_done(@translatable, "created") }  # defined in application_controller.rb
        format.json { render @translatable.class.name.underscore.pluralize+"/show", status: :created, location: @translation }
      else
        hsstatus = {status: :unprocessable_content}
        format.html { render :new, **hsstatus }
        format.json { render json: @translatable.errors, **hsstatus }
      end
    end
  end

    # @translation must be set.
    #
    # This sets @translatable
    #
    # @return [Boolean] the result of a save attempt
    def _set_save_translatable
      @translatable = @translation.translatable
      @translatable.translations << @translation  # Appends @translation (ID nil) to the in-memory Array
      if @translatable
        case @translation.is_orig
        when nil
          @translatable.orig_locale = nil
        when false
          if !@translatable.orig_locale
            add_flash_message(:alert, "is_orig is forcibly converted to nil", now: false)
          else
            # do nothing  # NOTE: if this Translation is the last one, is_orig should never be false. But if you implement a validation, you must consider the first Translation to save among multiple ones on :create, which is a bit complicated. I do nothing about it for now and leave it for operation.
          end
        else
          @translatable.orig_locale = @translation.langcode
        end
        return @translatable.save
      else
print "DEBUG: "; p @translation
        if @translation.valid?
          raise "translation with null translatable should fail in validation, but... "+@translation.inspect
        else
          return false
        end
      end
    end
    private :_set_save_translatable

  # PATCH/PUT /translations/1
  # PATCH/PUT /translations/1.json
  def update
    # hsparam = stripped_params(translation_params) # stripped_params defiend in Parent  # This would reject nullifying alt_title
    hsparam = translation_params
    hsparam = convert_params_bool(hsparam, :is_orig)  # is_orig can be nil, e.g., a general noun like car/voiture

    respond_to do |format|
      if @translation.update(hsparam)
        ########################## redirect_back???  # So far, the following is the same as def_respond_to_format() in application_controller.rb
        hskwds = {success: 'Translation was successfully updated.'}
        hskwds[:warning] = flash[:warning] if flash[:warning].present?
        format.html { redirect_to @translation, **hskwds}
        format.json { render :show, status: :ok, location: @translation }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @translation.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /translations/1
  # DELETE /translations/1.json
  def destroy
    @translation.destroy
    respond_to do |format|
        ########################## redirect_back??? (though tricky)
      format.html { redirect_to translations_url, notice: 'Translation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_translation
      @translation = Translation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def translation_params
      params.require(:translation).permit(:translatable_id, :translatable_type, :langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji, :is_orig, :weight, :create_user_id, :update_user_id, :note)
    end
end
