class Harami1129ReviewsController < ApplicationController
  before_action :set_harami1129_review, only: %i[ show edit update destroy ]
  load_and_authorize_resource

  H1129_INS_COLNAMES = %w(ins_singer ins_song)  # Column names of Harami1129

  # GET /harami1129_reviews or /harami1129_reviews.json
  def index
    @harami1129_reviews = Harami1129Review.all
  end

  # GET /harami1129_reviews/1 or /harami1129_reviews/1.json
  def show
  end

  # GET /harami1129_reviews/new
  def new
    @harami1129_review = Harami1129Review.new
  end

  # GET /harami1129_reviews/1/edit
  def edit
  end

  # POST /harami1129_reviews or /harami1129_reviews.json
  def create
    @harami1129_review = Harami1129Review.new(harami1129_review_params)

    respond_to do |format|
      if @harami1129_review.save
        format.html { redirect_to harami1129_review_url(@harami1129_review), notice: "Harami1129 review was successfully created." }
        format.json { render :show, status: :created, location: @harami1129_review }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @harami1129_review.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /harami1129_reviews/1 or /harami1129_reviews/1.json
  def update
    respond_to do |format|
      if @harami1129_review.update(harami1129_review_params)
        format.html { redirect_to harami1129_review_url(@harami1129_review), notice: "Harami1129 review was successfully updated." }
        format.json { render :show, status: :ok, location: @harami1129_review }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @harami1129_review.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /harami1129_reviews/1 or /harami1129_reviews/1.json
  def destroy
    @harami1129_review.destroy

    respond_to do |format|
      format.html { redirect_to harami1129_reviews_url, notice: "Harami1129 review was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_harami1129_review
      @harami1129_review = Harami1129Review.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def harami1129_review_params
#print "DEBUG:params=";p params
      params.require(:harami1129_review).permit(:harami1129_id, :harami1129_col_name, :harami1129_col_val, :engage_id, :checked, :user_id, :note)
    end
end
