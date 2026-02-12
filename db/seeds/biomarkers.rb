# Biomarker seed data for common lab tests
# Based on LOINC codes and typical reference ranges

biomarkers_data = [
  # Complete Blood Count (CBC)
  { name: "Hemoglobin", code: "718-7", unit: "g/dL", ref_min: 12.0, ref_max: 17.5 },
  { name: "White Blood Cell Count", code: "6690-2", unit: "10^3/uL", ref_min: 4.5, ref_max: 11.0 },
  { name: "Platelet Count", code: "777-3", unit: "10^3/uL", ref_min: 150.0, ref_max: 400.0 },
  { name: "Hematocrit", code: "4544-3", unit: "%", ref_min: 36.0, ref_max: 51.0 },
  { name: "Red Blood Cell Count", code: "789-8", unit: "10^6/uL", ref_min: 4.0, ref_max: 6.0 },

  # Metabolic Panel
  { name: "Glucose", code: "2345-7", unit: "mg/dL", ref_min: 70.0, ref_max: 100.0 },
  { name: "Creatinine", code: "2160-0", unit: "mg/dL", ref_min: 0.7, ref_max: 1.3 },
  { name: "Sodium", code: "2951-2", unit: "mmol/L", ref_min: 136.0, ref_max: 145.0 },
  { name: "Potassium", code: "2823-3", unit: "mmol/L", ref_min: 3.5, ref_max: 5.1 },
  { name: "Calcium", code: "17861-6", unit: "mg/dL", ref_min: 8.5, ref_max: 10.5 },
  { name: "BUN (Blood Urea Nitrogen)", code: "3094-0", unit: "mg/dL", ref_min: 7.0, ref_max: 20.0 },

  # Lipid Panel
  { name: "Total Cholesterol", code: "2093-3", unit: "mg/dL", ref_min: 0.0, ref_max: 200.0 },
  { name: "LDL Cholesterol", code: "2089-1", unit: "mg/dL", ref_min: 0.0, ref_max: 100.0 },
  { name: "HDL Cholesterol", code: "2085-9", unit: "mg/dL", ref_min: 40.0, ref_max: 999.0 },
  { name: "Triglycerides", code: "2571-8", unit: "mg/dL", ref_min: 0.0, ref_max: 150.0 },

  # Thyroid
  { name: "TSH", code: "3016-3", unit: "mIU/L", ref_min: 0.4, ref_max: 4.0 },
  { name: "Free T4", code: "3024-7", unit: "ng/dL", ref_min: 0.8, ref_max: 1.8 },
  { name: "Free T3", code: "3051-0", unit: "pg/mL", ref_min: 2.3, ref_max: 4.2 },

  # Vitamins
  { name: "Vitamin D", code: "1989-3", unit: "ng/mL", ref_min: 30.0, ref_max: 100.0 },
  { name: "Vitamin B12", code: "2132-9", unit: "pg/mL", ref_min: 200.0, ref_max: 900.0 },
  { name: "Folate", code: "2284-8", unit: "ng/mL", ref_min: 2.7, ref_max: 17.0 },

  # Liver Function
  { name: "ALT (Alanine Aminotransferase)", code: "1742-6", unit: "U/L", ref_min: 7.0, ref_max: 56.0 },
  { name: "AST (Aspartate Aminotransferase)", code: "1920-8", unit: "U/L", ref_min: 10.0, ref_max: 40.0 },
  { name: "Total Bilirubin", code: "1975-2", unit: "mg/dL", ref_min: 0.1, ref_max: 1.2 },
  { name: "Albumin", code: "1751-7", unit: "g/dL", ref_min: 3.5, ref_max: 5.5 },
  { name: "Alkaline Phosphatase", code: "6768-6", unit: "U/L", ref_min: 30.0, ref_max: 120.0 },

  # Inflammation
  { name: "CRP (C-Reactive Protein)", code: "1988-5", unit: "mg/L", ref_min: 0.0, ref_max: 3.0 },

  # Diabetes Monitoring
  { name: "HbA1c (Hemoglobin A1c)", code: "4548-4", unit: "%", ref_min: 0.0, ref_max: 5.6 },

  # Kidney Function
  { name: "eGFR (Estimated Glomerular Filtration Rate)", code: "33914-3", unit: "mL/min/1.73m2", ref_min: 60.0, ref_max: 120.0 },

  # Iron Studies
  { name: "Ferritin", code: "2276-4", unit: "ng/mL", ref_min: 12.0, ref_max: 300.0 },
  { name: "Iron", code: "2498-4", unit: "mcg/dL", ref_min: 60.0, ref_max: 170.0 }
]

# Create or update biomarkers (idempotent)
biomarkers_data.each do |data|
  Biomarker.find_or_create_by!(code: data[:code]) do |biomarker|
    biomarker.name = data[:name]
    biomarker.unit = data[:unit]
    biomarker.ref_min = data[:ref_min]
    biomarker.ref_max = data[:ref_max]
  end
end

puts "Seeded #{Biomarker.count} biomarkers"
