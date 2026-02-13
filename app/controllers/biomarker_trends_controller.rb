class BiomarkerTrendsController < ApplicationController
  before_action :set_biomarker

  def show
    # Query test results for current user and specified biomarker, ordered by test date
    @test_results = TestResult
      .joins(:biology_report)
      .where(biology_reports: { user: Current.user }, biomarker: @biomarker)
      .order("biology_reports.test_date ASC")

    # Return 404 when no data exists for user
    if @test_results.empty?
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    # Check if fewer than 2 data points
    if @test_results.size < 2
      @insufficient_data = true
      return
    end

    # Format data as JSON for Chart.js
    @chart_data = format_chart_data(@test_results)
  end

  private

  def set_biomarker
    @biomarker = Biomarker.find(params[:id])
  end

  def format_chart_data(test_results)
    # Extract test dates as labels
    labels = test_results.map { |result| result.biology_report.test_date.to_s }

    # Extract values and report IDs
    values = test_results.map(&:value)
    report_ids = test_results.map { |result| result.biology_report.id }

    # Get reference range from most recent result
    latest_result = test_results.last
    ref_min = latest_result.ref_min
    ref_max = latest_result.ref_max

    # Build Chart.js data structure
    {
      labels: labels,
      datasets: [
        {
          label: "#{@biomarker.name} (#{@biomarker.unit})",
          data: values,
          reportIds: report_ids,
          borderColor: "#3b82f6",
          backgroundColor: "rgba(59, 130, 246, 0.1)",
          tension: 0.4,
          pointRadius: 6,
          pointHoverRadius: 8
        }
      ],
      annotations: build_annotations(ref_min, ref_max)
    }
  end

  def build_annotations(ref_min, ref_max)
    return {} unless ref_min && ref_max

    {
      normalRange: {
        type: "box",
        yMin: ref_min,
        yMax: ref_max,
        backgroundColor: "rgba(34, 197, 94, 0.1)",
        borderColor: "rgba(34, 197, 94, 0.5)",
        borderWidth: 1,
        label: {
          display: true,
          content: "Normal Range (#{ref_min}-#{ref_max})",
          position: "start",
          color: "rgba(34, 197, 94, 1)",
          font: {
            size: 12
          }
        }
      }
    }
  end
end
