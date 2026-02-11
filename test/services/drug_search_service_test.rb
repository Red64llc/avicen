require "test_helper"

class DrugSearchServiceTest < ActiveSupport::TestCase
  setup do
    @aspirin = drugs(:aspirin)
    @ibuprofen = drugs(:ibuprofen)
  end

  # --- Short query rejection ---

  test "returns error for query shorter than 2 characters" do
    result = DrugSearchService.new(query: "a").call

    assert result.error?
    assert_not result.success?
  end

  test "returns error for empty query" do
    result = DrugSearchService.new(query: "").call

    assert result.error?
  end

  # --- Local-only results ---

  test "returns local results when drugs match the query" do
    result = DrugSearchService.new(query: "Aspirin").call

    assert result.success?
    assert_equal :local, result.source
    assert_includes result.drugs.map(&:name), @aspirin.name
  end

  test "returns local results with partial name match" do
    result = DrugSearchService.new(query: "Ibu").call

    assert result.success?
    assert_equal :local, result.source
    assert_includes result.drugs.map(&:name), @ibuprofen.name
  end

  # --- API call when no local matches ---

  test "calls RxNorm API when no local matches found" do
    stub_rxnorm_success("Metformin")

    result = DrugSearchService.new(query: "Metformin").call

    assert result.success?
    assert_equal :api, result.source
    assert_not_empty result.drugs
  end

  test "creates Drug records from RxNorm API data" do
    stub_rxnorm_success("Metformin")

    assert_difference "Drug.count", 2 do
      DrugSearchService.new(query: "Metformin").call
    end

    drug = Drug.find_by(rxcui: "861004")
    assert_not_nil drug
    assert_equal "Metformin hydrochloride 500 MG Oral Tablet", drug.name
  end

  test "filters RxNorm results by term type SCD and SBD only" do
    stub_rxnorm_with_mixed_term_types("Metformin")

    result = DrugSearchService.new(query: "Metformin").call

    assert result.success?
    # Should include SCD and SBD entries, exclude others (like IN, PIN)
    rxcuis = result.drugs.map(&:rxcui)
    assert_includes rxcuis, "861004"
    assert_includes rxcuis, "861007"
    assert_not_includes rxcuis, "6809" # IN type should be excluded
  end

  test "does not create duplicate Drug records for existing rxcui" do
    # Create a drug with an rxcui that will also appear in API results
    # but with a name that does NOT match the search query so local search returns empty
    Drug.create!(name: "Met HCl 500mg Tab", rxcui: "861004")

    stub_rxnorm_success("Metformin")

    # Only 1 new drug should be created (861007); 861004 already exists
    assert_difference "Drug.count", 1 do
      DrugSearchService.new(query: "Metformin").call
    end
  end

  # --- API failure fallback ---

  test "returns local results when API times out" do
    stub_request(:get, /rxnav\.nlm\.nih\.gov/)
      .to_timeout

    result = DrugSearchService.new(query: "Metformin").call

    assert result.success?
    assert_equal :local, result.source
  end

  test "returns local results when API returns HTTP error" do
    stub_request(:get, /rxnav\.nlm\.nih\.gov/)
      .to_return(status: 500, body: "Internal Server Error")

    result = DrugSearchService.new(query: "Metformin").call

    assert result.success?
    assert_equal :local, result.source
  end

  test "returns local results when API returns invalid JSON" do
    stub_request(:get, /rxnav\.nlm\.nih\.gov/)
      .to_return(status: 200, body: "not json", headers: { "Content-Type" => "application/json" })

    result = DrugSearchService.new(query: "Metformin").call

    assert result.success?
    assert_equal :local, result.source
  end

  test "logs warning when API is unavailable" do
    stub_request(:get, /rxnav\.nlm\.nih\.gov/)
      .to_timeout

    assert_logged(:warn) do
      DrugSearchService.new(query: "Metformin").call
    end
  end

  # --- Result object ---

  test "Result.success creates a successful result" do
    drugs = [ drugs(:aspirin) ]
    result = DrugSearchService::Result.success(drugs: drugs, source: :local)

    assert result.success?
    assert_not result.error?
    assert_equal drugs, result.drugs
    assert_equal :local, result.source
  end

  test "Result.error creates an error result" do
    result = DrugSearchService::Result.error(message: "Query too short")

    assert result.error?
    assert_not result.success?
  end

  private

  def stub_rxnorm_success(query)
    body = {
      drugGroup: {
        name: query,
        conceptGroup: [
          {
            tty: "SCD",
            conceptProperties: [
              { rxcui: "861004", name: "Metformin hydrochloride 500 MG Oral Tablet", tty: "SCD" },
              { rxcui: "861007", name: "Metformin hydrochloride 1000 MG Oral Tablet", tty: "SCD" }
            ]
          }
        ]
      }
    }.to_json

    stub_request(:get, "https://rxnav.nlm.nih.gov/REST/drugs.json?name=#{query}")
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
  end

  def stub_rxnorm_with_mixed_term_types(query)
    body = {
      drugGroup: {
        name: query,
        conceptGroup: [
          {
            tty: "IN",
            conceptProperties: [
              { rxcui: "6809", name: "Metformin", tty: "IN" }
            ]
          },
          {
            tty: "SCD",
            conceptProperties: [
              { rxcui: "861004", name: "Metformin hydrochloride 500 MG Oral Tablet", tty: "SCD" }
            ]
          },
          {
            tty: "SBD",
            conceptProperties: [
              { rxcui: "861007", name: "Glucophage 500 MG Oral Tablet", tty: "SBD" }
            ]
          }
        ]
      }
    }.to_json

    stub_request(:get, "https://rxnav.nlm.nih.gov/REST/drugs.json?name=#{query}")
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
  end

  def assert_logged(level, &block)
    logged = false
    original_logger = Rails.logger
    mock_logger = Class.new(original_logger.class) do
      define_method(level) do |*args, &log_block|
        logged = true
        super(*args, &log_block)
      end
    end.new($stdout)
    Rails.logger = mock_logger
    yield
    assert logged, "Expected a #{level} log message"
  ensure
    Rails.logger = original_logger
  end
end
