class BiomarkersController < ApplicationController
  def index
    # Query distinct biomarkers that have test results for current user
    @biomarkers = Biomarker
      .joins(:test_results)
      .joins("INNER JOIN biology_reports ON biology_reports.id = test_results.biology_report_id")
      .where(biology_reports: { user: Current.user })
      .select("biomarkers.*, COUNT(test_results.id) AS test_results_count")
      .group("biomarkers.id")
      .order("biomarkers.name ASC")
  end
end
