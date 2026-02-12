// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Configure Turbo progress bar to show after a short delay during navigation
// The progress bar appears automatically during Turbo visits that take longer than the delay
Turbo.setProgressBarDelay(200)
