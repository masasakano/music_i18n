class GenresController < ApplicationController
  before_action :set_genre, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource

  # GET /genres
  # GET /genres.json
  def index
    @genres = Genre.all.order(:weight)
  end

  # GET /genres/1
  # GET /genres/1.json
  def show
  end

  # GET /genres/new
  def new
    @genre = Genre.new
  end

  # GET /genres/1/edit
  def edit
  end

  # POST /genres
  # POST /genres.json
  def create
    @genre = Genre.new(genre_params)
    def_respond_to_format(@genre)  # defined in application_controller.rb
  end

  # PATCH/PUT /genres/1
  # PATCH/PUT /genres/1.json
  def update
    def_respond_to_format(@genre, :updated){
      @genre.update(genre_params)
    } # defined in application_controller.rb
  end

  # DELETE /genres/1
  # DELETE /genres/1.json
  def destroy
    @genre.destroy
    respond_to do |format|
      format.html { redirect_to genres_url, notice: 'Genre was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_genre
      @genre = Genre.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def genre_params
      params.require(:genre).permit(:weight, :note)
    end
end
