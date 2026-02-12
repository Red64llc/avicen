require "test_helper"

class PrescriptionsFormViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription = prescriptions(:one)
    sign_in_as(@user)
  end

  # --- New View Structure ---

  test "new view renders heading" do
    get new_prescription_path
    assert_response :success
    assert_select "h1", text: /New Prescription/
  end

  test "new view renders back link to prescriptions index" do
    get new_prescription_path
    assert_select "a[href=?]", prescriptions_path, text: /Back to Prescriptions/
  end

  test "new view wraps form in a card container" do
    get new_prescription_path
    assert_select "div.bg-white.shadow.rounded-lg"
  end

  # --- Edit View Structure ---

  test "edit view renders heading" do
    get edit_prescription_path(@prescription)
    assert_response :success
    assert_select "h1", text: /Edit Prescription/
  end

  test "edit view renders back link to prescription show" do
    get edit_prescription_path(@prescription)
    assert_select "a[href=?]", prescription_path(@prescription), text: /Back to Prescription/
  end

  # --- Form Fields ---

  test "form includes doctor_name text field" do
    get new_prescription_path
    assert_select "input[type='text'][name='prescription[doctor_name]']"
  end

  test "form includes prescribed_date date field" do
    get new_prescription_path
    assert_select "input[type='date'][name='prescription[prescribed_date]']"
  end

  test "form includes notes text area" do
    get new_prescription_path
    assert_select "textarea[name='prescription[notes]']"
  end

  test "form includes labels for all fields" do
    get new_prescription_path
    assert_select "label[for*='doctor_name']"
    assert_select "label[for*='prescribed_date']"
    assert_select "label[for*='notes']"
  end

  test "form includes submit button" do
    get new_prescription_path
    assert_select "input[type='submit']"
  end

  test "form includes cancel link" do
    get new_prescription_path
    assert_select "a", text: /Cancel/
  end

  test "new form cancel link points to prescriptions index" do
    get new_prescription_path
    assert_select "a[href=?]", prescriptions_path, text: /Cancel/
  end

  test "edit form cancel link points to prescription show" do
    get edit_prescription_path(@prescription)
    assert_select "a[href=?]", prescription_path(@prescription), text: /Cancel/
  end

  # --- Form Pre-filled Values (Edit) ---

  test "edit form pre-fills doctor name" do
    get edit_prescription_path(@prescription)
    assert_select "input[name='prescription[doctor_name]'][value=?]", @prescription.doctor_name
  end

  test "edit form pre-fills prescribed date" do
    get edit_prescription_path(@prescription)
    assert_select "input[name='prescription[prescribed_date]'][value=?]", @prescription.prescribed_date.to_s
  end

  test "edit form pre-fills notes" do
    get edit_prescription_path(@prescription)
    assert_select "textarea[name='prescription[notes]']", text: @prescription.notes
  end

  # --- Error Display ---

  test "form displays validation errors when submission fails" do
    post prescriptions_path, params: { prescription: { doctor_name: "", prescribed_date: nil } }
    assert_response :unprocessable_entity
    # Error section should be visible
    assert_select ".bg-red-50"
    assert_select "li", minimum: 1
  end

  # --- Responsive Layout ---

  test "form uses responsive padding" do
    get new_prescription_path
    # Card container should have responsive padding (p-4 sm:p-6)
    assert_select "div[class*='p-4'][class*='sm:p-6']"
  end

  test "form fields use full width on mobile" do
    get new_prescription_path
    # Inputs should be block w-full for mobile-first
    assert_select "input[class*='w-full']", minimum: 1
    assert_select "textarea[class*='w-full']", minimum: 1
  end

  # --- Form Reuse (Partial) ---

  test "new and edit views both render the same form partial" do
    get new_prescription_path
    new_body = response.body

    get edit_prescription_path(@prescription)
    edit_body = response.body

    # Both should have the same form structure (doctor_name, prescribed_date, notes fields)
    assert_select "input[name='prescription[doctor_name]']"
    assert_select "input[name='prescription[prescribed_date]']"
    assert_select "textarea[name='prescription[notes]']"

    # Both should have the form element
    assert_match(/<form/, new_body)
    assert_match(/<form/, edit_body)
  end
end
