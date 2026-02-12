#!/usr/bin/env ruby
# Display sample biomarker data for verification

require 'json'

# Read the seed file
seed_content = File.read('db/seeds/biomarkers.rb')

# Extract biomarker data
puts "=== Biomarker Seed Data Sample ==="
puts ""

# Sample biomarkers to display
samples = [
  { code: '718-7', panel: 'CBC' },
  { code: '2345-7', panel: 'Metabolic' },
  { code: '2093-3', panel: 'Lipid' },
  { code: '3016-3', panel: 'Thyroid' },
  { code: '1989-3', panel: 'Vitamins' },
  { code: '1742-6', panel: 'Liver Function' },
  { code: '1988-5', panel: 'Inflammation' }
]

samples.each do |sample|
  # Extract biomarker block
  pattern = /\{\s*name:\s*"([^"]+)"[^}]*code:\s*"#{sample[:code]}"[^}]*unit:\s*"([^"]+)"[^}]*ref_min:\s*([0-9.]+)[^}]*ref_max:\s*([0-9.]+)/m
  
  if match = seed_content.match(pattern)
    puts "Panel: #{sample[:panel]}"
    puts "  Name: #{match[1]}"
    puts "  Code: #{sample[:code]}"
    puts "  Unit: #{match[2]}"
    puts "  Range: #{match[3]} - #{match[4]} #{match[2]}"
    puts ""
  end
end

# Count by panel
puts "=== Panel Summary ==="
panels = {
  'CBC' => ['Hemoglobin', 'White Blood Cell', 'Platelet', 'Hematocrit'],
  'Metabolic' => ['Glucose', 'Creatinine', 'Sodium', 'Potassium'],
  'Lipid' => ['Total Cholesterol', 'LDL Cholesterol', 'HDL Cholesterol', 'Triglycerides'],
  'Thyroid' => ['TSH', 'Free T4', 'Free T3'],
  'Vitamins' => ['Vitamin D', 'Vitamin B12'],
  'Liver Function' => ['ALT', 'AST', 'Alkaline', 'Bilirubin', 'Albumin'],
  'Inflammation' => ['C-Reactive Protein']
}

panels.each do |panel_name, markers|
  count = markers.count { |marker| seed_content.include?(marker) }
  puts "#{panel_name}: #{count} markers"
end

puts ""
puts "Total biomarkers: #{seed_content.scan(/name:/).length}"
