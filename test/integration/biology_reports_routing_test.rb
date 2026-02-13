require "test_helper"

class BiologyReportsRoutingTest < ActionDispatch::IntegrationTest
  # RED Phase: Write failing tests for route configuration (task 9.1)
  # Requirements: 2.1, 3.1, 5.1, 6.4

  test "standard REST routes for biology_reports exist" do
    # RESTful CRUD routes (Requirement 2.1)
    assert_routing({ method: "get", path: "/biology_reports" },
                  { controller: "biology_reports", action: "index" })

    assert_routing({ method: "get", path: "/biology_reports/new" },
                  { controller: "biology_reports", action: "new" })

    assert_routing({ method: "post", path: "/biology_reports" },
                  { controller: "biology_reports", action: "create" })

    assert_routing({ method: "get", path: "/biology_reports/1" },
                  { controller: "biology_reports", action: "show", id: "1" })

    assert_routing({ method: "get", path: "/biology_reports/1/edit" },
                  { controller: "biology_reports", action: "edit", id: "1" })

    assert_routing({ method: "patch", path: "/biology_reports/1" },
                  { controller: "biology_reports", action: "update", id: "1" })

    assert_routing({ method: "delete", path: "/biology_reports/1" },
                  { controller: "biology_reports", action: "destroy", id: "1" })
  end

  test "nested test_results routes under biology_reports exist" do
    # Nested resource routes (Requirement 3.1)
    assert_routing(
      { method: "get", path: "/biology_reports/1/test_results/new" },
      { controller: "test_results", action: "new", biology_report_id: "1" }
    )

    assert_routing(
      { method: "post", path: "/biology_reports/1/test_results" },
      { controller: "test_results", action: "create", biology_report_id: "1" }
    )

    assert_routing(
      { method: "get", path: "/biology_reports/1/test_results/2/edit" },
      { controller: "test_results", action: "edit", biology_report_id: "1", id: "2" }
    )

    assert_routing(
      { method: "patch", path: "/biology_reports/1/test_results/2" },
      { controller: "test_results", action: "update", biology_report_id: "1", id: "2" }
    )

    assert_routing(
      { method: "delete", path: "/biology_reports/1/test_results/2" },
      { controller: "test_results", action: "destroy", biology_report_id: "1", id: "2" }
    )
  end

  test "custom biomarker search route exists" do
    # Biomarker autocomplete search (Requirement 5.1)
    assert_routing({ method: "get", path: "/biomarkers/search" },
                  { controller: "biomarker_search", action: "search" })
  end

  test "custom biomarker index route exists" do
    # Biomarker index for trend navigation (Requirement 6.4)
    assert_routing({ method: "get", path: "/biomarkers" },
                  { controller: "biomarkers", action: "index" })
  end

  test "custom biomarker trends route exists" do
    # Biomarker trend visualization (Requirement 5.1)
    # Note: Route uses :id parameter (Rails convention) which represents the biomarker_id
    # The controller accesses this via params[:id] in BiomarkerTrendsController
    assert_routing({ method: "get", path: "/biomarker_trends/1" },
                  { controller: "biomarker_trends", action: "show", id: "1" })
  end

  test "biology_reports_path helper generates correct URL" do
    assert_equal "/biology_reports", biology_reports_path
  end

  test "biology_report_path helper generates correct URL" do
    assert_equal "/biology_reports/1", biology_report_path(1)
  end

  test "new_biology_report_test_result_path helper generates correct URL" do
    assert_equal "/biology_reports/1/test_results/new",
                 new_biology_report_test_result_path(1)
  end

  test "biology_report_test_results_path helper generates correct URL" do
    assert_equal "/biology_reports/1/test_results",
                 biology_report_test_results_path(1)
  end

  test "edit_biology_report_test_result_path helper generates correct URL" do
    assert_equal "/biology_reports/1/test_results/2/edit",
                 edit_biology_report_test_result_path(1, 2)
  end

  test "biology_report_test_result_path helper generates correct URL" do
    assert_equal "/biology_reports/1/test_results/2",
                 biology_report_test_result_path(1, 2)
  end

  test "biomarkers_search_path helper generates correct URL" do
    assert_equal "/biomarkers/search", biomarkers_search_path
  end

  test "biomarkers_path helper generates correct URL" do
    assert_equal "/biomarkers", biomarkers_path
  end

  test "biomarker_trends_path helper generates correct URL" do
    assert_equal "/biomarker_trends/1", biomarker_trends_path(1)
  end

  test "biomarker trends route accepts biomarker as URL parameter name" do
    # Verify that the route parameter can be referred to as biomarker_id or id
    # The controller will receive params[:id] which represents the biomarker
    assert_recognizes(
      { controller: "biomarker_trends", action: "show", id: "5" },
      { method: :get, path: "/biomarker_trends/5" }
    )
  end
end
