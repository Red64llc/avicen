import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"
import annotationPlugin from "chartjs-plugin-annotation"

// Register Chart.js components and annotation plugin
Chart.register(...registerables, annotationPlugin)

// Connects to data-controller="biomarker-chart"
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    chartData: Object
  }

  connect() {
    // Handle missing data gracefully
    if (!this.hasChartDataValue || !this.chartDataValue.labels || this.chartDataValue.labels.length < 2) {
      console.warn("Insufficient data for chart rendering")
      return
    }

    this.initializeChart()
  }

  disconnect() {
    // Destroy chart to prevent memory leaks
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  initializeChart() {
    const ctx = this.canvasTarget.getContext("2d")
    const chartData = this.chartDataValue

    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: chartData.labels,
        datasets: chartData.datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 2,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: {
            display: true,
            position: "top"
          },
          tooltip: {
            enabled: true,
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.parsed.y}`
              }
            }
          },
          annotation: {
            annotations: chartData.annotations || {}
          }
        },
        scales: {
          y: {
            beginAtZero: false,
            title: {
              display: true,
              text: "Value"
            }
          },
          x: {
            title: {
              display: true,
              text: "Test Date"
            }
          }
        },
        // Make data points clickable
        onClick: (event, elements) => {
          if (elements.length > 0) {
            const dataIndex = elements[0].index
            const reportId = chartData.datasets[0].reportIds[dataIndex]
            
            if (reportId) {
              // Navigate to biology report detail page
              window.location.href = `/biology_reports/${reportId}`
            }
          }
        }
      }
    })
  }
}
