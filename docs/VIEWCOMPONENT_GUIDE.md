# ViewComponent: Do You Need It?

**Short answer:** It's optional. For a hackathon/MVP, **partials are fine**. ViewComponent shines when you have complex, reusable UI.

---

## ViewComponent vs Partials

| Aspect | Partials | ViewComponent |
|--------|----------|---------------|
| **Performance** | Slower (compiled at runtime) | ~2.5-10x faster (pre-compiled at startup) |
| **Testing** | Hard to test in isolation | 100x faster unit tests than controller tests |
| **Interface** | Implicit (instance variables) | Explicit (`initialize` defines inputs) |
| **Complexity** | Simple | More structure |

---

## When ViewComponent Helps

For Avicen, these UI elements would benefit:

```ruby
# app/components/medication_card_component.rb
class MedicationCardComponent < ViewComponent::Base
  def initialize(medication:, show_actions: true)
    @medication = medication
    @show_actions = show_actions
  end
end
```

**Good candidates:**
- Medication cards (used in daily view, weekly view, history)
- Biomarker trend charts (reused across reports, dashboard, sharing)
- Alert banners (drug interactions, missed doses)
- Schedule builder (complex form with multiple states)

**Not worth it:**
- One-off pages (settings, about)
- Simple forms
- Layouts

---

## Key Advantages

### 1. Explicit Interface

```ruby
# Partial - what does it need? Who knows...
<%= render "medication", locals: { medication: @med, user: @user, show_time: true } %>

# ViewComponent - crystal clear
<%= render MedicationCardComponent.new(medication: @med, show_actions: true) %>
```

### 2. Testable in Isolation

```ruby
# test/components/medication_card_component_test.rb
class MedicationCardComponentTest < ViewComponent::TestCase
  def test_renders_drug_name
    med = medications(:levothyroxine)
    render_inline(MedicationCardComponent.new(medication: med))

    assert_selector "h3", text: "Levothyroxine"
  end

  def test_hides_actions_when_disabled
    render_inline(MedicationCardComponent.new(medication: med, show_actions: false))

    assert_no_selector "button"
  end
end
```

### 3. Slots for Complex Layouts

```ruby
# app/components/card_component.rb
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :footer
  renders_many :actions
end
```

```erb
<%= render CardComponent.new do |card| %>
  <% card.with_header { "Medication Schedule" } %>
  <% card.with_action { link_to "Edit", edit_path } %>
  <% card.with_action { link_to "Delete", delete_path } %>
<% end %>
```

### 4. Previews (like Storybook)

```ruby
# test/components/previews/medication_card_component_preview.rb
class MedicationCardComponentPreview < ViewComponent::Preview
  def default
    render MedicationCardComponent.new(medication: Medication.first)
  end

  def without_actions
    render MedicationCardComponent.new(medication: Medication.first, show_actions: false)
  end
end
```

Visit `/rails/view_components` to see all component states.

---

## Recommendation for Avicen

**For MVP:** Start with partials. Add ViewComponent later for:
1. Components you render 10+ times per page (performance)
2. Components with complex logic (testability)
3. Components used in 3+ places (reusability)

### Installation (Optional)

```bash
# Add later if needed
bundle add view_component
```

---

## Sources

- [ViewComponent Official](https://viewcomponent.org/)
- [Why Choose ViewComponent](https://railsdesigner.com/why-choose-viewcomponent/)
- [Partials vs ViewComponent](https://msuliq.medium.com/partials-vs-view-components-in-ruby-on-rails-c9e4d2bb362c)
- [ViewComponent in the Wild (Evil Martians)](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-building-modern-rails-frontends)
- [Rails View Performance Benchmark](https://codescaptain.medium.com/rails-view-performance-partial-vs-component-real-benchmark-comparison-intermediate-senior-64d254f820cb)
