class DrugsController < ApplicationController
  def search
    query = params[:q].to_s.strip
    if query.length < 2
      head :ok
      return
    end

    result = DrugSearchService.new(query: query).call

    if result.success? && result.drugs.any?
      render partial: "drugs/search_results", locals: { drugs: result.drugs }, layout: false
    else
      head :ok
    end
  end
end
