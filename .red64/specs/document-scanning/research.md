# Research & Design Decisions: Document Scanning

---
**Purpose**: Capture discovery findings, architectural investigations, and rationale that inform the technical design.

**Usage**:
- Log research activities and outcomes during the discovery phase.
- Document design decision trade-offs that are too detailed for `design.md`.
- Provide references and evidence for future audits or reuse.
---

## Summary
- **Feature**: `document-scanning`
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  - RubyLLM gem provides unified vision API with automatic image encoding for Claude
  - Claude Vision API optimal image size is 1568px max dimension, ~1600 tokens per image
  - Active Storage direct uploads support progress events via JavaScript

## Research Log

### RubyLLM Vision Capabilities
- **Context**: Need to understand how to integrate Claude Vision for document extraction
- **Sources Consulted**:
  - [RubyLLM Documentation](https://rubyllm.com/chat/)
  - [GitHub - crmne/ruby_llm](https://github.com/crmne/ruby_llm)
- **Findings**:
  - Vision supported via `with:` parameter: `chat.ask("Describe", with: "path/to/image.png")`
  - Supports local file paths, URLs, and multiple images as arrays
  - Automatic image encoding and formatting for each provider's API
  - Supported formats: .jpg, .jpeg, .png, .gif, .webp, .bmp
  - Must select vision-capable model (Claude Sonnet 4.5 recommended)
  - Structured output via `RubyLLM::Schema` for guaranteed JSON structure
- **Implications**: Can pass Active Storage blob paths directly to ruby_llm; schema classes enforce extraction output format

### Claude Vision API Best Practices
- **Context**: Optimize image processing for document scanning accuracy and performance
- **Sources Consulted**:
  - [Claude Vision Documentation](https://platform.claude.com/docs/en/build-with-claude/vision)
- **Findings**:
  - Optimal image size: no more than 1.15 megapixels, within 1568px in both dimensions
  - Token estimation: `tokens = (width_px * height_px) / 750`
  - Supported formats: JPEG, PNG, GIF, WebP
  - API limit: 5MB per image (claude.ai: 10MB)
  - Max 100 images per API request
  - Best practice: place images before text/questions in prompts
  - Claude 3.5 Sonnet excels at text transcription from imperfect images
  - Cannot identify people in images (AUP restriction)
  - Limitations: may struggle with precise spatial reasoning, approximate counting
- **Implications**:
  - Resize images to max 1568px before sending to API
  - Use ~1600 tokens budget per image for cost estimation
  - Medical document scanning is supported use case

### Active Storage Direct Upload Progress
- **Context**: Implement upload progress indicator for user experience
- **Sources Consulted**:
  - [Rails Designer - ActiveStorage Direct Upload with Stimulus](https://railsdesigner.com/direct-upload-stimulus/)
  - [Rails Guides - Active Storage Overview](https://edgeguides.rubyonrails.org/active_storage_overview.html)
- **Findings**:
  - Built-in events: `direct-upload:initialize`, `direct-upload:start`, `direct-upload:progress`, `direct-upload:error`, `direct-upload:end`
  - `directUploadWillStoreFileWithXHR` method allows custom progress handlers
  - Turbo Drive may interfere with form submissions - need `data-turbo="false"` or proper handling
  - CORS configuration required for direct uploads to cloud storage
- **Implications**: Create Stimulus controller listening to direct upload events; handle Turbo compatibility

### Existing Codebase Patterns
- **Context**: Ensure alignment with established patterns in Avicen codebase
- **Sources Consulted**: Local codebase analysis via Grep
- **Findings**:
  - Service pattern: `DrugSearchService` with `Result` class (success/error factory methods)
  - Document validation: `DocumentValidator` validates PDF, JPEG, PNG
  - Active Storage: `BiologyReport` has `has_one_attached :document`
  - Stimulus controllers: autocomplete patterns in `drug_search_controller.js`, `biomarker_search_controller.js`
  - Solid Queue configured but no domain jobs implemented yet
- **Implications**: Follow DrugSearchService Result pattern; extend DocumentValidator for HEIC and size limits

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Hybrid | Extend existing models + new scanner services + dedicated scan controller | Clean separation, follows existing patterns, testable | Requires coordination between components | Recommended by gap analysis |
| Pure Extension | Add scanning to existing controllers | Minimal new files | Bloats existing controllers, harder to test | Not recommended |
| Separate Module | Namespace all scanning under `DocumentScanning::` | Maximum isolation | Over-engineering for current scope | Future consideration |

## Design Decisions

### Decision: Use Hybrid Approach for Architecture
- **Context**: Need to balance clean architecture with pragmatic code reuse
- **Alternatives Considered**:
  1. Extend existing controllers (SourcesController pattern)
  2. Create fully separate DocumentScanning module
- **Selected Approach**: Hybrid - extend models with attachments, create new scanner services and dedicated controller
- **Rationale**:
  - Keeps CRUD controllers focused
  - Scanner services can be tested in isolation
  - Follows existing DrugSearchService pattern
  - Phased implementation reduces risk
- **Trade-offs**: More files to navigate, but better separation of concerns
- **Follow-up**: Monitor complexity as features grow

### Decision: Use RubyLLM Schema for Structured Extraction
- **Context**: Need guaranteed JSON structure from Claude Vision responses
- **Alternatives Considered**:
  1. Request JSON in prompt, parse manually
  2. Use RubyLLM Schema classes
- **Selected Approach**: Define `PrescriptionExtractionSchema` and `BiologyReportExtractionSchema` classes
- **Rationale**:
  - Guarantees response matches exact schema with required fields
  - Better than manual JSON parsing with potential errors
  - Aligns with ruby_llm gem best practices
- **Trade-offs**: Additional schema classes to maintain
- **Follow-up**: Test schema validation with various image types

### Decision: Resize Images Before Claude API
- **Context**: Large images increase latency and cost without improving accuracy
- **Alternatives Considered**:
  1. Send original images, let API resize
  2. Compress aggressively (lossy)
  3. Resize to optimal dimensions (1568px max)
- **Selected Approach**: Resize to max 1568px dimension, preserve aspect ratio
- **Rationale**:
  - Claude documentation recommends this for optimal time-to-first-token
  - Reduces token usage (~1600 tokens per image at this size)
  - No accuracy loss vs larger images
- **Trade-offs**: Requires image processing step (MiniMagick/ImageMagick)
- **Follow-up**: Benchmark resize time vs API response time

### Decision: Simple File Input with Capture Attribute
- **Context**: Need camera capture for mobile users
- **Alternatives Considered**:
  1. Simple `<input type="file" capture="environment">`
  2. Custom getUserMedia implementation with preview
- **Selected Approach**: Start with simple file input, enhance later
- **Rationale**:
  - Works across all mobile browsers
  - Native OS handles camera permissions
  - Faster to implement
  - Can enhance with getUserMedia later if needed
- **Trade-offs**: Less control over camera UI
- **Follow-up**: Test on iOS Safari and Android Chrome

### Decision: Add Extraction Status to Existing Models
- **Context**: Need to track background extraction state
- **Alternatives Considered**:
  1. Add status fields to Prescription/BiologyReport models
  2. Create separate ScanSession model
- **Selected Approach**: Add `extraction_status` enum to Prescription and BiologyReport
- **Rationale**:
  - Simpler than new model
  - Status belongs to the record being created
  - Can query pending extractions easily
- **Trade-offs**: Adds fields to existing models
- **Follow-up**: Ensure migration is reversible

## Risks & Mitigations
- **Claude API rate limiting** - Implement retry with exponential backoff; queue jobs to spread load
- **Image quality affecting extraction accuracy** - Provide clear guidance; flag low-confidence results
- **Drug/biomarker fuzzy matching accuracy** - Always require user confirmation; allow custom entries
- **Mobile camera issues on iOS PWA** - Use simple file input with capture; test on real devices
- **Large images causing slow extraction** - Resize before sending; offer background processing

## References
- [RubyLLM Documentation](https://rubyllm.com/) - Unified Ruby LLM API
- [Claude Vision API Docs](https://platform.claude.com/docs/en/build-with-claude/vision) - Official vision documentation
- [Active Storage Direct Upload](https://edgeguides.rubyonrails.org/active_storage_overview.html#direct-uploads) - Rails guides
- [Rails Designer - Direct Upload with Stimulus](https://railsdesigner.com/direct-upload-stimulus/) - Implementation patterns
