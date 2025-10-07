class ModelSummariesController < ApplicationController
  include ModuleCommon # for split_hash_with_keys

  # before_action :set_model_summary, only: %i[ show edit update destroy ]
  load_and_authorize_resource

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(modelname note)

  # GET /model_summaries or /model_summaries.json
  def index
    @model_summaries = ModelSummary.all
  end

  # GET /model_summaries/1 or /model_summaries/1.json
  def show
  end

  # GET /model_summaries/new
  def new
    params.permit!
    @model_summary = ModelSummary.new(modelname: params[:modelname])
  end

  # GET /model_summaries/1/edit
  def edit
  end

  # POST /model_summaries or /model_summaries.json
  def create
    # Parameters: {"authenticity_token"=>"[FILTERED]", "model_summary"=>{"langcode"=>"en", "title"=>"another tes", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "modelname"=>"Something", "note"=>""}, "commit"=>"Create Model Summary", "locale"=>"en"}

    params.permit!
    hsprm = params.require(:model_summary).permit(
      :modelname, :note,
      :langcode, :is_orig, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji)

    hsprm.permit!

    hsmain = params[:model_summary].slice(*MAIN_FORM_KEYS)
    @model_summary = ModelSummary.new(**hsmain)

    hsprm_tra, resths = split_hash_with_keys(
                 params[:model_summary],
                 %w(langcode is_orig title ruby romaji alt_title alt_ruby alt_romaji))
    tra = Translation.preprocessed_new(**hsprm_tra)

    @model_summary.unsaved_translations << tra
    @model_summary.modelname = nil if @model_summary.modelname.present? && @model_summary.modelname.strip.blank?  # There should be a better way! (to avoid a blank parameter.)

    @msg_alerts = []

    respond_to do |format|
      if @model_summary.save
        format.html { redirect_to model_summary_url(@model_summary), notice: "ModelSummary was successfully created." }
        format.json { render :show, status: :created, location: @model_summary }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @model_summary.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /model_summaries/1 or /model_summaries/1.json
  def update
    params.permit!
    hsprm = params.require(:model_summary).permit(:modelname, :note)
    hsprm.permit!

    hsmain = params[:model_summary].slice(*MAIN_FORM_KEYS)
    hs2pass = hsmain

    def_respond_to_format(@model_summary, :updated){
      @model_summary.update(hs2pass)
    } # defined in application_controller.rb
  end

  # DELETE /model_summaries/1 or /model_summaries/1.json
  def destroy
    @model_summary.destroy

    respond_to do |format|
      format.html { redirect_to model_summaries_url, notice: "ModelSummary was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_model_summary
      @model_summary = ModelSummary.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def model_summary_params
      params.require(:model_summary).permit(MAIN_FORM_KEYS.map(&:to_sym))
    end
end
