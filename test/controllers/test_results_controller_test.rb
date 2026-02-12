require "test_helper"

class TestResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in_as @user
    @biology_report = biology_reports(:one)
    @test_result = test_results(:glucose_normal)
    @biomarker = biomarkers(:glucose)
  end

  # NEW ACTION TESTS
  test "should get new for authenticated user" do
    get new_biology_report_test_result_path(@biology_report)
    assert_response :success
    assert_select "form[action=?]", biology_report_test_results_path(@biology_report)
  end

  test "should get new with biomarker_id and auto-fill fields" do
    get new_biology_report_test_result_path(@biology_report), params: { biomarker_id: @biomarker.id }
    assert_response :success
    assert_select "input[name='test_result[unit]'][value=?]", @biomarker.unit
    assert_select "input[name='test_result[ref_min]'][value=?]", @biomarker.ref_min.to_s
    assert_select "input[name='test_result[ref_max]'][value=?]", @biomarker.ref_max.to_s
  end

  test "should not get new for other user's biology report" do
    other_report = biology_reports(:other_user_report)
    assert_raises(ActiveRecord::RecordNotFound) do
      get new_biology_report_test_result_path(other_report)
    end
  end

  # CREATE ACTION TESTS
  test "should create test result with valid params" do
    assert_difference("TestResult.count", 1) do
      post biology_report_test_results_path(@biology_report), params: {
        test_result: {
          biomarker_id: biomarkers(:wbc).id,
          value: 7.5,
          unit: "10^3/uL",
          ref_min: 4.5,
          ref_max: 11.0
        }
      }
    end

    assert_response :success
    assert_equal "turbo-stream", response.media_type

    test_result = TestResult.last
    assert_equal @biology_report.id, test_result.biology_report_id
    assert_equal biomarkers(:wbc).id, test_result.biomarker_id
    assert_equal 7.5, test_result.value
    assert_equal false, test_result.out_of_range
  end

  test "should flag out of range when creating test result" do
    assert_difference("TestResult.count", 1) do
      post biology_report_test_results_path(@biology_report), params: {
        test_result: {
          biomarker_id: @biomarker.id,
          value: 150.0,
          unit: "mg/dL",
          ref_min: 70.0,
          ref_max: 100.0
        }
      }
    end

    test_result = TestResult.last
    assert_equal true, test_result.out_of_range
  end

  test "should not create test result with missing biomarker" do
    assert_no_difference("TestResult.count") do
      post biology_report_test_results_path(@biology_report), params: {
        test_result: {
          value: 95.0,
          unit: "mg/dL"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create test result with non-numeric value" do
    assert_no_difference("TestResult.count") do
      post biology_report_test_results_path(@biology_report), params: {
        test_result: {
          biomarker_id: @biomarker.id,
          value: "invalid",
          unit: "mg/dL"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create test result for other user's biology report" do
    other_report = biology_reports(:other_user_report)
    assert_raises(ActiveRecord::RecordNotFound) do
      post biology_report_test_results_path(other_report), params: {
        test_result: {
          biomarker_id: @biomarker.id,
          value: 95.0,
          unit: "mg/dL"
        }
      }
    end
  end

  # EDIT ACTION TESTS
  test "should get edit for authenticated user" do
    get edit_biology_report_test_result_path(@biology_report, @test_result)
    assert_response :success
    assert_select "form[action=?]", biology_report_test_result_path(@biology_report, @test_result)
  end

  test "should not get edit for other user's test result" do
    other_report = biology_reports(:other_user_report)
    other_test_result = test_results(:glucose_high)
    other_test_result.update!(biology_report: other_report)

    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_biology_report_test_result_path(other_report, other_test_result)
    end
  end

  # UPDATE ACTION TESTS
  test "should update test result with valid params" do
    patch biology_report_test_result_path(@biology_report, @test_result), params: {
      test_result: {
        value: 92.0,
        unit: "mg/dL",
        ref_min: 70.0,
        ref_max: 100.0
      }
    }

    assert_response :success
    assert_equal "turbo-stream", response.media_type

    @test_result.reload
    assert_equal 92.0, @test_result.value
    assert_equal false, @test_result.out_of_range
  end

  test "should recalculate out_of_range flag on update" do
    patch biology_report_test_result_path(@biology_report, @test_result), params: {
      test_result: {
        value: 150.0
      }
    }

    @test_result.reload
    assert_equal true, @test_result.out_of_range
  end

  test "should not update test result with invalid value" do
    original_value = @test_result.value

    patch biology_report_test_result_path(@biology_report, @test_result), params: {
      test_result: {
        value: "invalid"
      }
    }

    assert_response :unprocessable_entity
    @test_result.reload
    assert_equal original_value, @test_result.value
  end

  test "should not update other user's test result" do
    other_report = biology_reports(:other_user_report)
    other_test_result = test_results(:glucose_high)
    other_test_result.update!(biology_report: other_report)

    assert_raises(ActiveRecord::RecordNotFound) do
      patch biology_report_test_result_path(other_report, other_test_result), params: {
        test_result: { value: 100.0 }
      }
    end
  end

  # DESTROY ACTION TESTS
  test "should destroy test result" do
    assert_difference("TestResult.count", -1) do
      delete biology_report_test_result_path(@biology_report, @test_result)
    end

    assert_response :success
    assert_equal "turbo-stream", response.media_type
  end

  test "should not destroy other user's test result" do
    other_report = biology_reports(:other_user_report)
    other_test_result = test_results(:glucose_high)
    other_test_result.update!(biology_report: other_report)

    assert_no_difference("TestResult.count") do
      assert_raises(ActiveRecord::RecordNotFound) do
        delete biology_report_test_result_path(other_report, other_test_result)
      end
    end
  end
end
