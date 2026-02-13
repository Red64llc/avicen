class BiomarkerSearchController < ApplicationController
  # GET /biomarkers/search
  # Returns HTML fragments (<li> elements) for stimulus-autocomplete
  #
  # Query parameters:
  #   q - Search term (minimum 2 characters)
  #
  # Returns:
  #   HTML fragments with data attributes for biomarker ID, name, code, unit, ref_min, ref_max
  #   Empty response if query is too short or no matches found
  #
  # Requirements: 1.2
  def search
    query = params[:q].to_s.strip

    # Return empty response for queries shorter than 2 characters
    if query.length < 2
      head :ok
      return
    end

    # Search biomarkers by name or code (case-insensitive)
    # Limit results to top 10 matches
    @biomarkers = Biomarker.autocomplete_search(query)

    if @biomarkers.any?
      render partial: "biomarker_search/search_results", locals: { biomarkers: @biomarkers }, layout: false
    else
      head :ok
    end
  end
end
