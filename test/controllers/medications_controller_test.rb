require "test_helper"

class MedicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @prescription = prescriptions(:one)
    @other_user_prescription = prescriptions(:other_user_prescription)
    @medication = medications(:aspirin_morning)
    @drug = drugs(:aspirin)
    @ibuprofen = drugs(:ibuprofen)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "new requires authentication" do
    sign_out
    get new_prescription_medication_path(@prescription)
    assert_redirected_to new_session_path
  end

  test "create requires authentication" do
    sign_out
    post prescription_medications_path(@prescription), params: {
      medication: { drug_id: @drug.id, dosage: "100mg", form: "tablet" }
    }
    assert_redirected_to new_session_path
  end

  test "edit requires authentication" do
    sign_out
    get edit_medication_path(@medication)
    assert_redirected_to new_session_path
  end

  test "update requires authentication" do
    sign_out
    patch medication_path(@medication), params: {
      medication: { dosage: "200mg" }
    }
    assert_redirected_to new_session_path
  end

  test "destroy requires authentication" do
    sign_out
    delete medication_path(@medication)
    assert_redirected_to new_session_path
  end

  test "toggle requires authentication" do
    sign_out
    patch toggle_medication_path(@medication)
    assert_redirected_to new_session_path
  end

  # --- New ---

  test "new renders the medication form inside a Turbo Frame" do
    get new_prescription_medication_path(@prescription)
    assert_response :success
    assert_select "turbo-frame"
    assert_select "form"
  end

  test "new returns not found for other user prescription" do
    get new_prescription_medication_path(@other_user_prescription)
    assert_response :not_found
  end

  # --- Create ---

  test "create with valid params creates medication nested under prescription" do
    assert_difference "Medication.count", 1 do
      post prescription_medications_path(@prescription), params: {
        medication: {
          drug_id: @ibuprofen.id,
          dosage: "400mg",
          form: "tablet",
          instructions: "Take with water"
        }
      }
    end

    medication = Medication.last
    assert_equal @prescription.id, medication.prescription_id
    assert_equal @ibuprofen.id, medication.drug_id
    assert_equal "400mg", medication.dosage
    assert_equal "tablet", medication.form
    assert_equal "Take with water", medication.instructions
    assert medication.active?
  end

  test "create associates medication with the correct drug" do
    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: @ibuprofen.id,
        dosage: "200mg",
        form: "capsule"
      }
    }

    medication = Medication.last
    assert_equal @ibuprofen, medication.drug
  end

  test "create responds with Turbo Frame for turbo request" do
    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: @drug.id,
        dosage: "100mg",
        form: "tablet"
      }
    }, headers: { "Turbo-Frame" => "medications" }

    # Should redirect to prescription show (which has the turbo frame)
    assert_response :redirect
  end

  test "create with invalid params re-renders form with errors" do
    assert_no_difference "Medication.count" do
      post prescription_medications_path(@prescription), params: {
        medication: {
          drug_id: nil,
          dosage: "",
          form: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create returns not found for other user prescription" do
    assert_no_difference "Medication.count" do
      post prescription_medications_path(@other_user_prescription), params: {
        medication: {
          drug_id: @drug.id,
          dosage: "100mg",
          form: "tablet"
        }
      }
    end

    assert_response :not_found
  end

  # --- Edit ---

  test "edit renders the medication form inside a Turbo Frame" do
    get edit_medication_path(@medication)
    assert_response :success
    assert_select "turbo-frame"
    assert_select "form"
  end

  test "edit returns not found for medication belonging to other user" do
    other_medication = medications(:inactive_medication)
    # inactive_medication belongs to prescription :two which belongs to user :one
    # We need a medication that belongs to other user
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    get edit_medication_path(other_med)
    assert_response :not_found
  end

  # --- Update ---

  test "update with valid params updates medication" do
    patch medication_path(@medication), params: {
      medication: {
        dosage: "200mg",
        form: "capsule",
        instructions: "Updated instructions"
      }
    }

    assert_response :redirect
    @medication.reload
    assert_equal "200mg", @medication.dosage
    assert_equal "capsule", @medication.form
    assert_equal "Updated instructions", @medication.instructions
  end

  test "update with invalid params re-renders form with errors" do
    patch medication_path(@medication), params: {
      medication: { dosage: "", form: "" }
    }

    assert_response :unprocessable_entity
  end

  test "update returns not found for medication belonging to other user" do
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    patch medication_path(other_med), params: {
      medication: { dosage: "999mg" }
    }

    assert_response :not_found
    other_med.reload
    assert_equal "50mg", other_med.dosage
  end

  # --- Destroy ---

  test "destroy deletes medication and redirects" do
    assert_difference "Medication.count", -1 do
      delete medication_path(@medication)
    end

    assert_response :redirect
  end

  test "destroy returns not found for medication belonging to other user" do
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    assert_no_difference "Medication.count" do
      delete medication_path(other_med)
    end

    assert_response :not_found
  end

  # --- Toggle ---

  test "toggle switches medication from active to inactive" do
    assert @medication.active?

    patch toggle_medication_path(@medication)

    @medication.reload
    assert_not @medication.active?
  end

  test "toggle switches medication from inactive to active" do
    inactive = medications(:inactive_medication)
    assert_not inactive.active?

    patch toggle_medication_path(inactive)

    inactive.reload
    assert inactive.active?
  end

  test "toggle responds with Turbo Stream" do
    patch toggle_medication_path(@medication), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "toggle returns not found for medication belonging to other user" do
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet",
      active: true
    )

    patch toggle_medication_path(other_med)
    assert_response :not_found
    other_med.reload
    assert other_med.active?
  end

  # --- User Scoping ---

  test "medication access is scoped through current user prescriptions" do
    # Create a medication under the other user's prescription
    other_prescription = prescriptions(:other_user_prescription)
    other_med = Medication.create!(
      prescription: other_prescription,
      drug: @drug,
      dosage: "50mg",
      form: "tablet"
    )

    # All member actions should return not found
    get edit_medication_path(other_med)
    assert_response :not_found

    patch medication_path(other_med), params: { medication: { dosage: "999mg" } }
    assert_response :not_found

    delete medication_path(other_med)
    assert_response :not_found

    patch toggle_medication_path(other_med)
    assert_response :not_found
  end

  # --- Form View Features ---

  test "new form renders drug search autocomplete with stimulus controller" do
    get new_prescription_medication_path(@prescription)
    assert_response :success
    assert_select "[data-controller='drug-search']"
    assert_select "input[data-drug-search-target='input']"
    assert_select "input[data-drug-search-target='hidden']"
  end

  test "new form renders dosage field" do
    get new_prescription_medication_path(@prescription)
    assert_response :success
    assert_select "input[name='medication[dosage]']"
  end

  test "new form renders form select with medication form options" do
    get new_prescription_medication_path(@prescription)
    assert_response :success
    assert_select "select[name='medication[form]']"
    assert_select "select[name='medication[form]'] option[value='tablet']"
    assert_select "select[name='medication[form]'] option[value='capsule']"
    assert_select "select[name='medication[form]'] option[value='liquid']"
  end

  test "new form renders instructions textarea" do
    get new_prescription_medication_path(@prescription)
    assert_response :success
    assert_select "textarea[name='medication[instructions]']"
  end

  test "edit form pre-fills drug name in autocomplete input" do
    get edit_medication_path(@medication)
    assert_response :success
    assert_select "input[data-drug-search-target='input'][value=?]", @medication.drug.name
  end

  # --- Strong Parameters ---

  test "create ignores prescription_id in params" do
    other_prescription = prescriptions(:other_user_prescription)

    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: @drug.id,
        dosage: "100mg",
        form: "tablet",
        prescription_id: other_prescription.id
      }
    }

    medication = Medication.last
    assert_equal @prescription.id, medication.prescription_id
    assert_not_equal other_prescription.id, medication.prescription_id
  end
end
