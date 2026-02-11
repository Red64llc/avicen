class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[home]

  def home
    # Landing page for unauthenticated users.
    # Authenticated users are routed to the dashboard via AuthenticatedConstraint,
    # so they never reach this action.
  end
end
