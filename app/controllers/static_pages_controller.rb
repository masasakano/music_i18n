class StaticPagesController < ApplicationController
  include ModuleCommon

  before_action :set_static_page, only: %i[ show edit update destroy ]
  load_and_authorize_resource

  # @param kwd [StaticPage, String, Symbol] if String, it is {StaticPage#mname}.
  # @option locale [String, NilClass] if nil is explicitly specified, locale is not prefixed.
  # @return [String]
  def self.public_path(kwd, locale=I18n.locale)
    mname = (kwd.respond_to?(:mname) ? kwd.mname : kwd.to_s)
    ret = '/'+mname
    locale.blank? ? ret : '/'+locale.to_s+ret
  end

  # GET /static_pages or /static_pages.json
  def index
    @static_pages = StaticPage.all.order(:mname)
  end

  # GET /static_pages/1 or /static_pages/1.json
  def show
  end

  # GET /static_pages/new
  def new
    @static_page = StaticPage.new
    @static_page.commit_message = 'Initial commit.'
  end

  # GET /static_pages/1/edit
  def edit
  end

  # POST /static_pages or /static_pages.json
  def create
    hs_uniq, hs_params = split_hash_with_keys(static_page_params, ["commit_message"])
    @static_page = StaticPage.new(hs_params)
    @static_page.commit_message = hs_uniq["commit_message"]

    respond_to do |format|
      if @static_page.save
        format.html { redirect_to @static_page, notice: "Static page was successfully created." }
        format.json { render :show, status: :created, location: @static_page }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @static_page.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /static_pages/1 or /static_pages/1.json
  def update
    hs_uniq, hs_params = split_hash_with_keys(static_page_params, ["commit_message"])
    hs_params.each_pair do |ek, ev|
      @static_page.send ek.to_s+'=', ev
    end
    @static_page.commit_message = hs_uniq["commit_message"]

    respond_to do |format|
      # if @static_page.update(static_page_params)
      if @static_page.save
        format.html { redirect_to @static_page, notice: "Static page was successfully updated." }
        format.json { render :show, status: :ok, location: @static_page }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @static_page.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /static_pages/1 or /static_pages/1.json
  def destroy
    @static_page.destroy
    respond_to do |format|
      format.html { redirect_to static_pages_url, notice: "Static page was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_static_page
      @static_page = StaticPage.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def static_page_params
      params.require(:static_page).permit(:langcode, :mname, :title, :page_format_id, :summary, :content, :note, :commit_message)
    end
end
