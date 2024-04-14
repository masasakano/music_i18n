class PlayRolesController < ApplicationController
  #before_action :set_play_role, only: %i[ show edit update destroy ]
  load_and_authorize_resource  # except: [:index, :show]  # This sets @play_roles.

  # GET /play_roles or /play_roles.json
  def index
    @play_roles = PlayRole.all.order(:weight)
  end

  # GET /play_roles/1 or /play_roles/1.json
  def show
  end

  # GET /play_roles/new
  def new
    @play_role = PlayRole.new
  end

  # GET /play_roles/1/edit
  def edit
  end

  # POST /play_roles or /play_roles.json
  def create
    @play_role = PlayRole.new(play_role_params)

    respond_to do |format|
      if @play_role.save
        format.html { redirect_to play_role_url(@play_role), notice: "PlayRole was successfully created." }
        format.json { render :show, status: :created, location: @play_role }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @play_role.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /play_roles/1 or /play_roles/1.json
  def update
    respond_to do |format|
      if @play_role.update(play_role_params)
        format.html { redirect_to play_role_url(@play_role), notice: "PlayRole was successfully updated." }
        format.json { render :show, status: :ok, location: @play_role }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @play_role.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /play_roles/1 or /play_roles/1.json
  def destroy
    @play_role.destroy

    respond_to do |format|
      format.html { redirect_to play_roles_url, notice: "PlayRole was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_play_role
      @play_role = PlayRole.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def play_role_params
      params.require(:play_role).permit(:mname, :weight, :note)
    end
end
