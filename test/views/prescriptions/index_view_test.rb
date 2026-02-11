require "test_helper"

class PrescriptionsIndexViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @prescription_one = prescriptions(:one)    # Dr. Smith, 2026-01-15
    @prescription_two = prescriptions(:two)    # Dr. Johnson, 2026-02-01
    sign_in_as(@user)
  end

  # --- Layout and Structure ---

  test "index renders page title" do
    get prescriptions_path
    assert_response :success
    assert_select "h1", text: /Prescriptions/
  end

  test "index renders new prescription link" do
    get prescriptions_path
    assert_select "a[href=?]", new_prescription_path, text: /New Prescription/
  end

  test "index wraps content in a max-width container" do
    get prescriptions_path
    assert_select "div.max-w-4xl"
  end

  # --- Prescription List ---

  test "index displays all user prescriptions" do
    get prescriptions_path
    assert_select ".prescription-card", count: 2
  end

  test "index displays doctor name for each prescription" do
    get prescriptions_path
    assert_match @prescription_one.doctor_name, response.body
    assert_match @prescription_two.doctor_name, response.body
  end

  test "index displays prescribed date for each prescription" do
    get prescriptions_path
    assert_match @prescription_one.prescribed_date.strftime("%B %d, %Y"), response.body
    assert_match @prescription_two.prescribed_date.strftime("%B %d, %Y"), response.body
  end

  test "index displays prescriptions ordered by prescribed date descending" do
    get prescriptions_path
    # prescription_two (2026-02-01) should appear before prescription_one (2026-01-15)
    two_pos = response.body.index(@prescription_two.doctor_name)
    one_pos = response.body.index(@prescription_one.doctor_name)
    assert two_pos < one_pos, "Most recent prescription should appear first"
  end

  test "index displays active medication count per prescription" do
    get prescriptions_path
    # prescription_one has 2 active medications (aspirin_morning + ibuprofen_evening)
    assert_select ".prescription-card" do |cards|
      card_one_html = cards.detect { |c| c.to_s.include?(@prescription_one.doctor_name) }
      assert card_one_html, "Should find card for #{@prescription_one.doctor_name}"
      assert_match(/2 active\s+medications/, card_one_html.to_s)
    end
  end

  test "index displays zero active medications for prescription with only inactive medications" do
    get prescriptions_path
    # prescription_two has 1 inactive medication
    assert_select ".prescription-card" do |cards|
      card_two_html = cards.detect { |c| c.to_s.include?(@prescription_two.doctor_name) }
      assert card_two_html, "Should find card for #{@prescription_two.doctor_name}"
      assert_match(/0 active\s+medications/, card_two_html.to_s)
    end
  end

  test "index shows prescription notes when present" do
    get prescriptions_path
    assert_match @prescription_one.notes, response.body
  end

  # --- Links and Actions ---

  test "index links doctor name to prescription show page" do
    get prescriptions_path
    assert_select "a[href=?]", prescription_path(@prescription_one)
    assert_select "a[href=?]", prescription_path(@prescription_two)
  end

  test "index displays edit link for each prescription" do
    get prescriptions_path
    assert_select "a[href=?]", edit_prescription_path(@prescription_one), text: /Edit/
    assert_select "a[href=?]", edit_prescription_path(@prescription_two), text: /Edit/
  end

  test "index displays delete button for each prescription" do
    get prescriptions_path
    assert_select "button", text: /Delete/, count: 2
  end

  test "index delete button has turbo confirm dialog" do
    get prescriptions_path
    assert_select "[data-turbo-confirm]", minimum: 2
  end

  # --- Empty State ---

  test "index displays empty state when no prescriptions exist" do
    # Delete all prescriptions for user
    @user.prescriptions.destroy_all
    get prescriptions_path
    assert_match(/don.t have any prescriptions/i, response.body)
    assert_select "a[href=?]", new_prescription_path
  end

  # --- Responsive Layout ---

  test "index cards use responsive flex layout" do
    get prescriptions_path
    # Cards should use flex-col on mobile, flex-row on sm breakpoint
    assert_select ".prescription-card" do |cards|
      cards.each do |card|
        inner_html = card.to_s
        assert inner_html.include?("sm:flex-row") || inner_html.include?("sm:items-center"),
          "Prescription cards should use responsive layout classes"
      end
    end
  end
end
