class ProfilesController < ApplicationController
  # Authentication is required by default (inherited from ApplicationController)

  before_action :set_profile, only: %i[edit update]

  def new
    @profile = Current.user.build_profile
  end

  def create
    @profile = Current.user.build_profile(profile_params)

    if @profile.save
      redirect_to root_path, notice: "Profile created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @profile.update(profile_params)
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html { redirect_to edit_profile_path, notice: "Profile updated successfully." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = Current.user.profile
  end

  def profile_params
    params.require(:profile).permit(:name, :date_of_birth, :timezone)
  end
end
