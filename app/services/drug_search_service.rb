class DrugSearchService
  RXNORM_BASE_URL = "https://rxnav.nlm.nih.gov/REST/drugs.json"
  TIMEOUT_SECONDS = 5
  MINIMUM_QUERY_LENGTH = 2
  ALLOWED_TERM_TYPES = %w[SCD SBD].freeze

  class Result
    attr_reader :drugs, :source, :error_message

    def initialize(success:, drugs: [], source: nil, error_message: nil)
      @success = success
      @drugs = drugs
      @source = source
      @error_message = error_message
      freeze
    end

    def success?
      @success
    end

    def error?
      !@success
    end

    def self.success(drugs:, source:)
      new(success: true, drugs: drugs, source: source)
    end

    def self.error(message:)
      new(success: false, error_message: message)
    end
  end

  def initialize(query:)
    @query = query.to_s.strip
  end

  def call
    return Result.error(message: "Query must be at least #{MINIMUM_QUERY_LENGTH} characters") if @query.length < MINIMUM_QUERY_LENGTH

    local_drugs = search_local
    return Result.success(drugs: local_drugs, source: :local) if local_drugs.any?

    api_drugs = search_rxnorm_api
    if api_drugs.any?
      Result.success(drugs: api_drugs, source: :api)
    else
      Result.success(drugs: local_drugs, source: :local)
    end
  end

  private

  def search_local
    Drug.search_by_name(@query)
  end

  def search_rxnorm_api
    response = fetch_from_rxnorm
    return [] unless response

    parse_and_create_drugs(response)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    Rails.logger.warn("RxNorm API unavailable: #{e.message}")
    []
  rescue StandardError => e
    Rails.logger.warn("RxNorm API error: #{e.class} - #{e.message}")
    []
  end

  def fetch_from_rxnorm
    uri = URI("#{RXNORM_BASE_URL}?name=#{URI.encode_www_form_component(@query)}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.warn("RxNorm API returned invalid JSON: #{e.message}")
    nil
  end

  def parse_and_create_drugs(data)
    concept_groups = data.dig("drugGroup", "conceptGroup")
    return [] unless concept_groups.is_a?(Array)

    drugs = []

    concept_groups.each do |group|
      next unless ALLOWED_TERM_TYPES.include?(group["tty"])

      properties = group["conceptProperties"]
      next unless properties.is_a?(Array)

      properties.each do |prop|
        drug = find_or_create_drug(prop)
        drugs << drug if drug
      end
    end

    drugs
  end

  def find_or_create_drug(prop)
    rxcui = prop["rxcui"]
    name = prop["name"]

    return nil if rxcui.blank? || name.blank?

    existing = Drug.find_by(rxcui: rxcui)
    return existing if existing

    Drug.create!(name: name, rxcui: rxcui)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    Drug.find_by(rxcui: rxcui)
  end
end
