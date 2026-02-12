require "test_helper"

class PrescriptionsShowViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription = prescriptions(:one)  # Dr. Smith, 2026-01-15, with 2 medications
    sign_in_as(@user)
  end

  # --- Layout and Structure ---

  test "show renders prescription doctor name as heading" do
    get prescription_path(@prescription)
    assert_response :success
    assert_select "h1", text: /#{@prescription.doctor_name}/
  end

  test "show renders back link to prescriptions index" do
    get prescription_path(@prescription)
    assert_select "a[href=?]", prescriptions_path, text: /Back to Prescriptions/
  end

  test "show wraps content in a max-width container" do
    get prescription_path(@prescription)
    assert_select "div.max-w-4xl"
  end

  # --- Prescription Details ---

  test "show displays prescribed date" do
    get prescription_path(@prescription)
    assert_match @prescription.prescribed_date.strftime("%B %d, %Y"), response.body
  end

  test "show displays notes when present" do
    get prescription_path(@prescription)
    assert_match @prescription.notes, response.body
  end

  test "show displays no doctor specified when doctor name is blank" do
    @prescription.update_column(:doctor_name, nil)
    get prescription_path(@prescription)
    assert_match(/No doctor specified/i, response.body)
  end

  # --- Action Buttons ---

  test "show displays edit link" do
    get prescription_path(@prescription)
    assert_select "a[href=?]", edit_prescription_path(@prescription), text: /Edit/
  end

  test "show displays delete button with confirmation" do
    get prescription_path(@prescription)
    assert_select "button", text: /Delete/
    assert_select "[data-turbo-confirm]"
  end

  # --- Medications Section ---

  test "show displays medications heading" do
    get prescription_path(@prescription)
    assert_select "h2", text: /Medications/
  end

  test "show displays all associated medications" do
    get prescription_path(@prescription)
    @prescription.medications.includes(:drug).each do |medication|
      assert_match medication.drug.name, response.body
      assert_match medication.dosage, response.body
      assert_match medication.form, response.body
    end
  end

  test "show displays medication drug name" do
    get prescription_path(@prescription)
    aspirin = medications(:aspirin_morning)
    assert_match aspirin.drug.name, response.body
  end

  test "show displays medication dosage and form" do
    get prescription_path(@prescription)
    aspirin = medications(:aspirin_morning)
    assert_match aspirin.dosage, response.body
    assert_match aspirin.form, response.body
  end

  test "show displays medication instructions when present" do
    get prescription_path(@prescription)
    aspirin = medications(:aspirin_morning)
    assert_match aspirin.instructions, response.body if aspirin.instructions.present?
  end

  test "show displays active status badge for active medications" do
    get prescription_path(@prescription)
    assert_match(/Active/, response.body)
  end

  test "show displays inactive status badge for inactive medications" do
    # prescription_two has an inactive medication
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    assert_match(/Inactive/, response.body)
  end

  test "show visually distinguishes inactive medications" do
    prescription_two = prescriptions(:two)
    get prescription_path(prescription_two)
    # Inactive medications should have reduced opacity or different styling
    assert_select "[class*='opacity']", minimum: 1
  end

  test "show displays empty message when no medications" do
    # Create a prescription with no medications
    empty_prescription = @user.prescriptions.create!(prescribed_date: Date.current, doctor_name: "Dr. Empty")
    get prescription_path(empty_prescription)
    assert_match(/No medications added/i, response.body)
  end

  # --- Responsive Layout ---

  test "show detail section uses responsive grid" do
    get prescription_path(@prescription)
    assert_select "dl.grid"
  end

  test "show medication items use responsive layout" do
    get prescription_path(@prescription)
    # Medication items should use flex layout with sm breakpoint
    assert_match(/sm:flex-row|sm:items-center/, response.body)
  end
end
