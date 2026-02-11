module SetTimezone
  extend ActiveSupport::Concern

  included do
    around_action :set_timezone
  end

  private

  def set_timezone(&block)
    timezone = current_timezone
    Time.use_zone(timezone, &block)
  end

  def current_timezone
    Current.user&.profile&.timezone.presence || "UTC"
  end
end
