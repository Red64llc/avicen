# Routing constraint that checks if a request comes from an authenticated user.
# Used to differentiate between authenticated and unauthenticated requests at
# the routing layer for dual-root routing (dashboard vs landing page).
#
# Usage in routes.rb:
#   root "dashboard#show", constraints: AuthenticatedConstraint
#   root "pages#home"
#
class AuthenticatedConstraint
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false unless session_id

    Session.exists?(id: session_id)
  end
end
