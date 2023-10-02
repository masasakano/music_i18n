class EngageHowsController < ApplicationController
  before_action :set_engage_how, only: %i[ show edit update destroy ]

  # GET /engage_hows or /engage_hows.json
  def index
    @engage_hows = EngageHow.order(:weight) # Same as EngageHow.all.sort, but DB-level sort
  end

  # GET /engage_hows/1 or /engage_hows/1.json
  def show
  end

  # GET /engage_hows/new
  def new
    @engage_how = EngageHow.new
  end

  # GET /engage_hows/1/edit
  def edit
  end

  # POST /engage_hows or /engage_hows.json
  def create
#logger.debug "DEBUG:Start: EngageHow.count="+EngageHow.count.to_s
    received = engage_how_params
    hsmain      = stripped_params received[:note] # stripped_params defiend in Parent
    hstrnas_prm = stripped_params received[:translation]

    hstrnas_prm[:is_orig] = (hstrnas_prm[:is_orig] ? hstrnas_prm[:is_orig].to_i : -99) # n.b., should never be nil if submitted normally.
    hstrnas_prm[:is_orig] =
      if hstrnas_prm[:is_orig] == 0
        false
      elsif hstrnas_prm[:is_orig] > 0
        true
      else
        nil
      end

    messages = []
    if Translation.valid_main_params? hstrnas_prm, messages: messages
      hs_trans = {translation: hstrnas_prm}
#logger.debug "DEBUG:hs_trans=#{hs_trans.inspect}"
      begin
        @engage_how = EngageHow.create_with_translation!(hsmain, **hs_trans)
      rescue ActiveRecord::RecordInvalid => err
        messages << err.message
      rescue ArgumentError => err
        raise if !err.message.include? 'update_or_create_translation_core' # ArgumentError ((update_or_create_translation_core) title is mandatory but is unspecified.):
        messages << 'title is mandatory but is unspecified.'
      end
    end

    if !@engage_how
      @engage_how = EngageHow.new(note: hsmain[:note])
      @engage_how.errors.add :base, (messages[0] || "Invalid Translation")
    end

    result_save = false
    if @engage_how.errors.size == 0
      begin
        result_save = @engage_how.save
      rescue ActiveRecord::RecordInvalid
        # If Translation is invalid, this exception is raised.
      end
    end

    respond_to do |format|
      if result_save
        format.html { redirect_to @engage_how, success: "EngageHow was successfully created." } # "success" defined in /app/controllers/application_controller.rb
        format.json { render :show, status: :created, location: @engage_how }
      else
        flash.alert = messages[0]
        logger.info "failed in creating #{@engage_how.class.name}: messages=#{messages.inspect}"
        #format.html { redirect_to new_engage_how_url, alert: messages[0] }
        format.html { render :new, status: :unprocessable_entity } # NOTE: alert: messages[0] does not work.
        format.json { render json: @engage_how.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /engage_hows/1 or /engage_hows/1.json
  def update
    respond_to do |format|
      if @engage_how.update(params.require(:engage_how).permit(:weight, :note))
        format.html { redirect_to @engage_how, notice: "Engage how was successfully updated." }
        format.json { render :show, status: :ok, location: @engage_how }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @engage_how.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /engage_hows/1 or /engage_hows/1.json
  def destroy
    @engage_how.destroy
    respond_to do |format|
      format.html { redirect_to engage_hows_url, notice: "EngageHow was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_engage_how
      @engage_how = EngageHow.find(params[:id])
    end

    # Only allow a list of trusted parameters through. create only (NOT update)
    def engage_how_params
      #params.require(:engage_how).permit([translation: [:langcode, :is_orig, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], engage_how: [:note]])
      params.require([:translation, :engage_how])
      # params[:translation].require([:title]) # raises, if title is left empty, which can happen, ActionController::ParameterMissing: param is missing or the value is empty: title

      params.permit([translation: [:langcode, :is_orig, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], engage_how: [:weight, :note]])
    end
end
