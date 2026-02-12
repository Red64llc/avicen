require "test_helper"

class MedicationViewsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription = prescriptions(:one)
    @medication = medications(:aspirin_morning)
    @inactive_medication = medications(:inactive_medication)
    @drug = drugs(:aspirin)
    @ibuprofen = drugs(:ibuprofen)
    sign_in_as(@user)
  end

  # ==========================================================================
  # Medication Form -- Drug Autocomplete (Req 3.5)
  # ==========================================================================

  test "new form renders drug-search stimulus controller wrapper" do
    get new_prescription_medication_path(@prescription)
    assert_response :success
    assert_select "[data-controller='drug-search']"
  end

  test "new form renders autocomplete text input for drug search" do
    get new_prescription_medication_path(@prescription)
    assert_select "input[data-drug-search-target='input'][type='text']"
  end

  test "new form renders hidden input for drug_id capture" do
    get new_prescription_medication_path(@prescription)
    assert_select "input[data-drug-search-target='hidden'][name='medication[drug_id]']"
  end

  test "new form renders autocomplete results list container" do
    get new_prescription_medication_path(@prescription)
    assert_select "ul[data-drug-search-target='results']"
  end

  test "new form configures drug-search url value to drugs search endpoint" do
    get new_prescription_medication_path(@prescription)
    assert_select "[data-drug-search-url-value='/drugs/search']"
  end

  test "new form configures minimum search length of 2 characters" do
    get new_prescription_medication_path(@prescription)
    assert_select "[data-drug-search-min-length-value='2']"
  end

  test "edit form pre-fills drug name in autocomplete input" do
    get edit_medication_path(@medication)
    assert_response :success
    assert_select "input[data-drug-search-target='input'][value=?]", @medication.drug.name
  end

  test "edit form pre-fills hidden drug_id with existing drug id" do
    get edit_medication_path(@medication)
    assert_select "input[data-drug-search-target='hidden'][value=?]", @medication.drug_id.to_s
  end

  # ==========================================================================
  # Medication Form -- Fields (Req 3.2, 3.5)
  # ==========================================================================

  test "new form renders dosage text field" do
    get new_prescription_medication_path(@prescription)
    assert_select "input[name='medication[dosage]']"
  end

  test "new form renders form select with all required options" do
    get new_prescription_medication_path(@prescription)
    assert_select "select[name='medication[form]']" do
      assert_select "option[value='tablet']", text: "Tablet"
      assert_select "option[value='capsule']", text: "Capsule"
      assert_select "option[value='liquid']", text: "Liquid"
      assert_select "option[value='injection']", text: "Injection"
      assert_select "option[value='inhaler']", text: "Inhaler"
      assert_select "option[value='patch']", text: "Patch"
      assert_select "option[value='drops']", text: "Drops"
      assert_select "option[value='cream']", text: "Cream"
      assert_select "option[value='suppository']", text: "Suppository"
    end
  end

  test "new form renders form select with blank prompt" do
    get new_prescription_medication_path(@prescription)
    assert_select "select[name='medication[form]'] option[value='']", text: /Select/
  end

  test "new form renders instructions textarea" do
    get new_prescription_medication_path(@prescription)
    assert_select "textarea[name='medication[instructions]']"
  end

  test "new form renders submit button with Add Medication text" do
    get new_prescription_medication_path(@prescription)
    assert_select "input[type='submit'][value='Add Medication']"
  end

  test "edit form renders submit button with Update Medication text" do
    get edit_medication_path(@medication)
    assert_select "input[type='submit'][value='Update Medication']"
  end

  test "new form renders cancel link back to prescription" do
    get new_prescription_medication_path(@prescription)
    assert_select "a[href=?]", prescription_path(@prescription), text: /Cancel/
  end

  test "form displays validation errors when present" do
    post prescription_medications_path(@prescription), params: {
      medication: { drug_id: nil, dosage: "", form: "" }
    }
    assert_response :unprocessable_entity
    assert_select "[class*='red']", minimum: 1
  end

  # ==========================================================================
  # Medication Form -- Turbo Frame Wrapping (Req 3.6)
  # ==========================================================================

  test "new form is wrapped in medication_form turbo frame" do
    get new_prescription_medication_path(@prescription)
    assert_select "turbo-frame#medication_form"
  end

  test "edit form is wrapped in medication_form turbo frame" do
    get edit_medication_path(@medication)
    assert_select "turbo-frame#medication_form"
  end

  test "new form renders heading Add Medication" do
    get new_prescription_medication_path(@prescription)
    assert_select "h2", text: /Add Medication/
  end

  test "edit form renders heading Edit Medication" do
    get edit_medication_path(@medication)
    assert_select "h2", text: /Edit Medication/
  end

  # ==========================================================================
  # Medication List Partial in Prescription Show (Req 3.6)
  # ==========================================================================

  test "prescription show renders medications list inside a turbo frame" do
    get prescription_path(@prescription)
    assert_response :success
    assert_select "turbo-frame#medications"
  end

  test "prescription show renders each medication with a unique dom id" do
    get prescription_path(@prescription)
    @prescription.medications.each do |medication|
      assert_select "##{ActionView::RecordIdentifier.dom_id(medication)}"
    end
  end

  test "prescription show renders medication drug name" do
    get prescription_path(@prescription)
    @prescription.medications.includes(:drug).each do |medication|
      assert_match medication.drug.name, response.body
    end
  end

  test "prescription show renders medication dosage and form" do
    get prescription_path(@prescription)
    @prescription.medications.each do |medication|
      assert_match medication.dosage, response.body
      assert_match medication.form, response.body
    end
  end

  test "prescription show renders medication instructions when present" do
    get prescription_path(@prescription)
    @prescription.medications.each do |medication|
      if medication.instructions.present?
        assert_match medication.instructions, response.body
      end
    end
  end

  test "prescription show renders add medication button linking to new medication" do
    get prescription_path(@prescription)
    assert_select "a[href=?]", new_prescription_medication_path(@prescription), text: /Add Medication/
  end

  test "prescription show renders empty medication_form turbo frame placeholder" do
    get prescription_path(@prescription)
    assert_select "turbo-frame#medication_form"
  end

  test "add medication link targets the medication_form turbo frame" do
    get prescription_path(@prescription)
    assert_select "a[data-turbo-frame='medication_form'][href=?]", new_prescription_medication_path(@prescription)
  end

  # ==========================================================================
  # Toggle Control (Req 3.7)
  # ==========================================================================

  test "medication item renders toggle button for active medication" do
    get prescription_path(@prescription)
    assert_select "form[action=?]", toggle_medication_path(@medication) do
      assert_select "button", text: /Deactivate/
    end
  end

  test "medication item renders toggle button for inactive medication" do
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    assert_select "form[action=?]", toggle_medication_path(@inactive_medication) do
      assert_select "button", text: /Activate/
    end
  end

  test "toggle button uses turbo stream for in-place update" do
    get prescription_path(@prescription)
    # button_to with data: { turbo_stream: true } enables turbo stream response
    assert_match(/data-turbo-stream/, response.body)
  end

  test "toggle turbo stream response replaces the medication element" do
    patch toggle_medication_path(@medication), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    dom_id = ActionView::RecordIdentifier.dom_id(@medication)
    assert_match dom_id, response.body
  end

  # ==========================================================================
  # Inactive Medication Visual Distinction (Req 3.8)
  # ==========================================================================

  test "active medication does not have reduced opacity" do
    get prescription_path(@prescription)
    active_dom_id = ActionView::RecordIdentifier.dom_id(@medication)
    # Active medications should NOT have opacity-60 class
    element = css_select("##{active_dom_id}").first
    assert element, "Expected to find element with id #{active_dom_id}"
    refute_match(/opacity-60/, element["class"].to_s)
  end

  test "inactive medication has reduced opacity styling" do
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    inactive_dom_id = ActionView::RecordIdentifier.dom_id(@inactive_medication)
    assert_select "##{inactive_dom_id}[class*='opacity']"
  end

  test "active medication has white background" do
    get prescription_path(@prescription)
    active_dom_id = ActionView::RecordIdentifier.dom_id(@medication)
    assert_select "##{active_dom_id}[class*='bg-white']"
  end

  test "inactive medication has gray background" do
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    inactive_dom_id = ActionView::RecordIdentifier.dom_id(@inactive_medication)
    assert_select "##{inactive_dom_id}[class*='bg-gray']"
  end

  test "active medication displays Active badge" do
    get prescription_path(@prescription)
    active_dom_id = ActionView::RecordIdentifier.dom_id(@medication)
    assert_select "##{active_dom_id}" do
      assert_select "span", text: "Active"
    end
  end

  test "inactive medication displays Inactive badge" do
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    inactive_dom_id = ActionView::RecordIdentifier.dom_id(@inactive_medication)
    assert_select "##{inactive_dom_id}" do
      assert_select "span", text: "Inactive"
    end
  end

  test "active badge uses green styling" do
    get prescription_path(@prescription)
    assert_select "span[class*='bg-green'][class*='text-green']", text: "Active"
  end

  test "inactive badge uses gray styling" do
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    assert_select "span[class*='bg-gray'][class*='text-gray']", text: "Inactive"
  end

  # ==========================================================================
  # Medication Item Actions (Edit/Remove)
  # ==========================================================================

  test "medication item renders edit link targeting medication_form turbo frame" do
    get prescription_path(@prescription)
    assert_select "a[href=?][data-turbo-frame='medication_form']", edit_medication_path(@medication), text: /Edit/
  end

  test "medication item renders remove button with confirmation" do
    get prescription_path(@prescription)
    # button_to generates form + button; turbo_confirm may be on either element
    assert_select "form[action=?]", medication_path(@medication) do
      assert_select "button", text: /Remove/
    end
    # Verify confirmation dialog is present (data-turbo-confirm on form or button)
    assert_match(/data-turbo-confirm/, response.body)
  end

  # ==========================================================================
  # Turbo Stream Templates (Req 3.6, 11.4)
  # ==========================================================================

  test "create turbo stream appends medication to medications_list" do
    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: @ibuprofen.id,
        dosage: "500mg",
        form: "liquid"
      }
    }, as: :turbo_stream

    assert_response :success
    # Should contain turbo-stream append action targeting medications_list
    assert_match(/turbo-stream.*action="append".*target="medications_list"/m, response.body)
  end

  test "create turbo stream clears the medication_form frame" do
    post prescription_medications_path(@prescription), params: {
      medication: {
        drug_id: @ibuprofen.id,
        dosage: "500mg",
        form: "liquid"
      }
    }, as: :turbo_stream

    assert_response :success
    # Should contain turbo-stream update to clear medication_form
    assert_match(/turbo-stream.*action="update".*target="medication_form"/m, response.body)
  end

  test "update turbo stream replaces medication element" do
    patch medication_path(@medication), params: {
      medication: { dosage: "999mg" }
    }, as: :turbo_stream

    assert_response :success
    dom_id = ActionView::RecordIdentifier.dom_id(@medication)
    assert_match(/turbo-stream.*action="replace".*target="#{dom_id}"/m, response.body)
  end

  test "update turbo stream clears the medication_form frame" do
    patch medication_path(@medication), params: {
      medication: { dosage: "999mg" }
    }, as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream.*action="update".*target="medication_form"/m, response.body)
  end

  test "destroy turbo stream removes medication element" do
    dom_id = ActionView::RecordIdentifier.dom_id(@medication)
    delete medication_path(@medication), as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream.*action="remove".*target="#{dom_id}"/m, response.body)
  end

  # ==========================================================================
  # Mobile-First Responsive Layout (Req 11.4)
  # ==========================================================================

  test "medication form uses responsive tailwind classes" do
    get new_prescription_medication_path(@prescription)
    # Form fields should have full-width responsive sizing
    assert_select "input[class*='w-full']", minimum: 1
    assert_select "select[class*='w-full']", minimum: 1
  end

  test "medication items use responsive flex layout" do
    get prescription_path(@prescription)
    # Medication items should adapt from column to row at sm breakpoint
    assert_match(/sm:flex-row/, response.body)
  end
end
