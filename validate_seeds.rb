#!/usr/bin/env ruby
# Validate biomarker seed data structure

require 'yaml'

# Read the seed file
seed_content = File.read('db/seeds/biomarkers.rb')

# Extract biomarkers_data array
biomarkers_match = seed_content.match(/biomarkers_data = \[(.*?)\]/m)
if biomarkers_match.nil?
  puts "ERROR: Could not find biomarkers_data array"
  exit 1
end

# Count biomarker entries
biomarker_count = seed_content.scan(/\{\s*name:/).length
puts "Found #{biomarker_count} biomarkers"

# Verify count is in range
if biomarker_count < 20
  puts "ERROR: Expected at least 20 biomarkers, found #{biomarker_count}"
  exit 1
elsif biomarker_count > 30
  puts "WARNING: Expected at most 30 biomarkers, found #{biomarker_count}"
end

# Check for required fields in each biomarker
required_fields = ['name:', 'code:', 'unit:', 'ref_min:', 'ref_max:']
biomarker_blocks = seed_content.scan(/\{[^}]+\}/m)

biomarker_blocks.each_with_index do |block, index|
  missing_fields = required_fields.select { |field| !block.include?(field) }
  if missing_fields.any?
    puts "ERROR: Biomarker #{index + 1} is missing fields: #{missing_fields.join(', ')}"
    exit 1
  end
end

# Check for LOINC code format (digits-digits)
codes = seed_content.scan(/code: "([^"]+)"/)
codes.each do |code_array|
  code = code_array[0]
  unless code.match?(/^\d+-\d+$/)
    puts "ERROR: Invalid LOINC code format: #{code} (expected format: 'NNN-N')"
    exit 1
  end
end

# Verify idempotent pattern
unless seed_content.include?('find_or_initialize_by')
  puts "ERROR: Seed file should use find_or_initialize_by for idempotency"
  exit 1
end

puts "✓ All validations passed"
puts "✓ #{biomarker_count} biomarkers with valid structure"
puts "✓ All LOINC codes valid"
puts "✓ Idempotent pattern detected"
