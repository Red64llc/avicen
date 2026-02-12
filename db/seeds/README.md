# Biomarker Seed Data

## Overview

This directory contains seed data for the biomarker catalog used in the Biology Reports feature.

## Files

- `biomarkers.rb` - Seed data for common biomarkers with LOINC codes and reference ranges

## Biomarker Coverage

The seed data includes 28 common biomarkers covering:

### Complete Blood Count (CBC) - 4 biomarkers
- Hemoglobin (718-7)
- White Blood Cell Count (6690-2)
- Platelet Count (777-3)
- Hematocrit (4544-3)

### Metabolic Panel - 6 biomarkers
- Glucose (2345-7)
- Creatinine (2160-0)
- Sodium (2951-2)
- Potassium (2823-3)
- Calcium (17861-6)
- Blood Urea Nitrogen/BUN (3094-0)

### Lipid Panel - 4 biomarkers
- Total Cholesterol (2093-3)
- LDL Cholesterol (2089-1)
- HDL Cholesterol (2085-9)
- Triglycerides (2571-8)

### Thyroid Panel - 3 biomarkers
- TSH (3016-3)
- Free T4 (3024-7)
- Free T3 (3051-0)

### Vitamins - 2 biomarkers
- Vitamin D/25-Hydroxyvitamin D (1989-3)
- Vitamin B12 (2132-9)

### Liver Function - 5 biomarkers
- ALT/Alanine Aminotransferase (1742-6)
- AST/Aspartate Aminotransferase (1920-8)
- Alkaline Phosphatase (6768-6)
- Total Bilirubin (1975-2)
- Albumin (1751-7)

### Inflammation - 1 biomarker
- C-Reactive Protein/CRP (1988-5)

### Additional Markers - 3 biomarkers
- Hemoglobin A1c (4548-4) - Diabetes marker
- Ferritin (2276-4) - Iron storage
- Iron (2498-4) - Iron level

## LOINC Codes

All biomarkers use LOINC (Logical Observation Identifiers Names and Codes) compatible codes in the format `NNNN-N` or `NNNNN-N`.

## Reference Ranges

Reference ranges provided are population averages. Some markers (e.g., Hemoglobin, Hematocrit) have different ranges for males and females. Labs may use slightly different ranges, and users can override these values when entering test results.

## Usage

To seed the database:

```bash
bin/rails db:seed
```

Or to seed only biomarkers:

```bash
bin/rails runner "load Rails.root.join('db', 'seeds', 'biomarkers.rb')"
```

## Idempotency

The seed script uses `find_or_initialize_by(code: ...)` to ensure it can be run multiple times without creating duplicates. Running the seeds again will:
- Create new biomarkers that don't exist
- Update existing biomarkers if data has changed
- Skip unchanged biomarkers

## Data Sources

Reference ranges are based on:
- LOINC database (loinc.org)
- Common clinical laboratory reference ranges
- Mayo Clinic reference values
- LabCorp and Quest Diagnostics reference ranges

## Future Enhancements

- Gender-specific reference ranges
- Age-specific reference ranges
- Pregnancy-specific reference ranges
- Additional biomarker categories (hormones, cardiac markers, etc.)
