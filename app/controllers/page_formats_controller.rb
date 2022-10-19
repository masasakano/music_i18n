class PageFormatsController < ApplicationController
  before_action :set_page_format, only: %i[ show edit update destroy ]
  load_and_authorize_resource

  # GET /page_formats or /page_formats.json
  def index
    @page_formats = PageFormat.all
  end

  # GET /page_formats/1 or /page_formats/1.json
  def show
  end

  # GET /page_formats/new
  def new
    @page_format = PageFormat.new
  end

  # GET /page_formats/1/edit
  def edit
  end

  # POST /page_formats or /page_formats.json
  def create
    @page_format = PageFormat.new(page_format_params)

    def_respond_to_format(@page_format)      # defined in application_controller.rb
  end

  # PATCH/PUT /page_formats/1 or /page_formats/1.json
  def update
    def_respond_to_format(@page_format, :updated){ 
      @page_format.update(page_format_params)
    } # defined in application_controller.rb
  end

  # DELETE /page_formats/1 or /page_formats/1.json
  def destroy
    @page_format.destroy
    respond_to do |format|
      format.html { redirect_to page_formats_url, notice: "Page format was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_page_format
      @page_format = PageFormat.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def page_format_params
      params.require(:page_format).permit(:mname, :description, :note)
    end
end
