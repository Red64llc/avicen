class DashboardController < ApplicationController
  # Authentication is required by default (inherited from ApplicationController)

  def show
    @user = Current.user
    @profile = @user.profile
  end
end
