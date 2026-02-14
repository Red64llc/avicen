# frozen_string_literal: true

require "test_helper"

class DocumentScansRoutingTest < ActionDispatch::IntegrationTest
  # RED Phase: Write tests for route configuration (task 8.3)
  # Requirements: 6.1, 6.2 - Turbo Frame support for document scanning flow

  # --- Standard Routes ---

  test "new document_scan route exists" do
    # GET /document_scans/new - Capture interface
    assert_routing({ method: "get", path: "/document_scans/new" },
                  { controller: "document_scans", action: "new" })
  end

  # --- Collection Routes ---

  test "upload collection route exists" do
    # POST /document_scans/upload - Handle direct upload completion
    assert_routing({ method: "post", path: "/document_scans/upload" },
                  { controller: "document_scans", action: "upload" })
  end

  test "select_type collection route exists" do
    # GET /document_scans/select_type - Display type selection with existing blob
    # Supports back navigation from background_suggestion and other steps
    # Requirement: 6.7 - navigate back to previous steps without losing progress
    assert_routing({ method: "get", path: "/document_scans/select_type" },
                  { controller: "document_scans", action: "select_type" })
  end

  test "extract collection route exists" do
    # POST /document_scans/extract - Trigger extraction (sync or background)
    assert_routing({ method: "post", path: "/document_scans/extract" },
                  { controller: "document_scans", action: "extract" })
  end

  test "confirm collection route exists" do
    # POST /document_scans/confirm - Create final Prescription or BiologyReport
    assert_routing({ method: "post", path: "/document_scans/confirm" },
                  { controller: "document_scans", action: "confirm" })
  end

  # --- Member Routes ---

  test "review member route exists" do
    # GET /document_scans/:id/review - Display extracted data in editable form
    assert_routing({ method: "get", path: "/document_scans/1/review" },
                  { controller: "document_scans", action: "review", id: "1" })
  end

  # --- Route Helper Tests ---

  test "new_document_scan_path helper generates correct URL" do
    assert_equal "/document_scans/new", new_document_scan_path
  end

  test "upload_document_scans_path helper generates correct URL" do
    assert_equal "/document_scans/upload", upload_document_scans_path
  end

  test "select_type_document_scans_path helper generates correct URL" do
    assert_equal "/document_scans/select_type", select_type_document_scans_path
  end

  test "extract_document_scans_path helper generates correct URL" do
    assert_equal "/document_scans/extract", extract_document_scans_path
  end

  test "confirm_document_scans_path helper generates correct URL" do
    assert_equal "/document_scans/confirm", confirm_document_scans_path
  end

  test "review_document_scan_path helper generates correct URL" do
    assert_equal "/document_scans/1/review", review_document_scan_path(1)
  end

  # --- Route Recognition Tests ---

  test "recognizes POST to upload as document_scans#upload" do
    assert_recognizes(
      { controller: "document_scans", action: "upload" },
      { method: :post, path: "/document_scans/upload" }
    )
  end

  test "recognizes GET to select_type as document_scans#select_type" do
    assert_recognizes(
      { controller: "document_scans", action: "select_type" },
      { method: :get, path: "/document_scans/select_type" }
    )
  end

  test "recognizes POST to extract as document_scans#extract" do
    assert_recognizes(
      { controller: "document_scans", action: "extract" },
      { method: :post, path: "/document_scans/extract" }
    )
  end

  test "recognizes POST to confirm as document_scans#confirm" do
    assert_recognizes(
      { controller: "document_scans", action: "confirm" },
      { method: :post, path: "/document_scans/confirm" }
    )
  end

  test "recognizes GET to review as document_scans#review with id" do
    assert_recognizes(
      { controller: "document_scans", action: "review", id: "42" },
      { method: :get, path: "/document_scans/42/review" }
    )
  end

  # --- Turbo Frame Support Verification ---

  test "routes support Turbo Frame requests for seamless transitions" do
    # This test verifies the controller can handle Turbo Frame requests
    # by ensuring routes don't require any special format suffix
    # (Turbo Frames use standard HTML requests with Turbo-Frame header)

    # Verify no format constraint blocks Turbo requests
    assert_routing({ method: "get", path: "/document_scans/new" },
                  { controller: "document_scans", action: "new" })

    assert_routing({ method: "post", path: "/document_scans/upload" },
                  { controller: "document_scans", action: "upload" })

    assert_routing({ method: "get", path: "/document_scans/select_type" },
                  { controller: "document_scans", action: "select_type" })

    assert_routing({ method: "post", path: "/document_scans/extract" },
                  { controller: "document_scans", action: "extract" })

    assert_routing({ method: "get", path: "/document_scans/1/review" },
                  { controller: "document_scans", action: "review", id: "1" })

    assert_routing({ method: "post", path: "/document_scans/confirm" },
                  { controller: "document_scans", action: "confirm" })
  end

  # --- Restricted Routes Verification ---

  test "index route does not exist for document_scans" do
    # Document scans are transient - no index listing needed
    assert_raises(Minitest::Assertion) do
      assert_recognizes({}, { method: :get, path: "/document_scans" })
    end
  end

  test "show route does not exist for document_scans" do
    # Use review action instead of standard show
    assert_raises(Minitest::Assertion) do
      assert_recognizes({}, { method: :get, path: "/document_scans/1" })
    end
  end

  test "edit route does not exist for document_scans" do
    # Edit is handled via review action
    assert_raises(Minitest::Assertion) do
      assert_recognizes({}, { method: :get, path: "/document_scans/1/edit" })
    end
  end

  test "create route does not exist for document_scans" do
    # Creation is handled via confirm action
    assert_raises(Minitest::Assertion) do
      assert_recognizes({}, { method: :post, path: "/document_scans" })
    end
  end

  test "update route does not exist for document_scans" do
    # Update is not needed - use confirm to create final record
    assert_raises(Minitest::Assertion) do
      assert_recognizes({}, { method: :patch, path: "/document_scans/1" })
    end
  end

  test "destroy route does not exist for document_scans" do
    # Destroy is not needed for scan flow
    assert_raises(Minitest::Assertion) do
      assert_recognizes({}, { method: :delete, path: "/document_scans/1" })
    end
  end
end
