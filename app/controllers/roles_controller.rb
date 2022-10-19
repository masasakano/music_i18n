class RolesController < ApplicationController
  before_action :set_role, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource

  # GET /roles
  # GET /roles.json
  def index
    @roles = Role.all
  end

  # GET /roles/1
  # GET /roles/1.json
  def show
  end

  # GET /roles/new
  def new
    @role = Role.new
  end

  # GET /roles/1/edit
  def edit
  end

  # POST /roles
  # POST /roles.json
  def create
    @role = Role.new(role_params)
    def_respond_to_format(@role)  # defined in application_controller.rb
  end

  # PATCH/PUT /roles/1
  # PATCH/PUT /roles/1.json
  def update
    def_respond_to_format(@role, :updated){ 
      @role.update(role_params)
    } # defined in application_controller.rb
  end

  # DELETE /roles/1
  # DELETE /roles/1.json
  def destroy
    @role.destroy
    respond_to do |format|
      format.html { redirect_to roles_url, notice: 'Role was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_role
      @role = Role.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def role_params
      params.require(:role).permit(:name, :uname, :role_category_id, :weight, :note)
    end
end
