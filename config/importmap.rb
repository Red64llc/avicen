# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "stimulus-autocomplete", to: "stimulus-autocomplete.js" # @3.1.0

# Chart.js for biomarker trend visualization
# Using auto module from CDN which provides proper ESM exports
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/+esm"
pin "chartjs-plugin-annotation", to: "https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1/+esm"
