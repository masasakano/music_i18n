class RoleCategoriesController < ApplicationController
  before_action :set_role_category, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource

  # GET /role_categories
  # GET /role_categories.json
  def index
    @role_categories = RoleCategory.all
  end

  # GET /role_categories/1
  # GET /role_categories/1.json
  def show
  end

  # GET /role_categories/new
  def new
    @role_category = RoleCategory.new
  end

  # GET /role_categories/1/edit
  def edit
  end

  # POST /role_categories
  # POST /role_categories.json
  def create
    @role_category = RoleCategory.new(role_category_params)

    respond_to do |format|
      if @role_category.save
        format.html { redirect_to @role_category, notice: 'Role category was successfully created.' }
        format.json { render :show, status: :created, location: @role_category }
      else
        format.html { render :new }
        format.json { render json: @role_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /role_categories/1
  # PATCH/PUT /role_categories/1.json
  def update
    respond_to do |format|
      if @role_category.update(role_category_params)
        format.html { redirect_to @role_category, notice: 'Role category was successfully updated.' }
        format.json { render :show, status: :ok, location: @role_category }
      else
        format.html { render :edit }
        format.json { render json: @role_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /role_categories/1
  # DELETE /role_categories/1.json
  def destroy
    @role_category.destroy
    respond_to do |format|
      format.html { redirect_to role_categories_url, notice: 'Role category was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_role_category
      @role_category = RoleCategory.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def role_category_params
      params.require(:role_category).permit(:mname, :note)
    end
end
