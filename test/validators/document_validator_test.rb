require "test_helper"
require "ostruct"

class DocumentValidatorTest < ActiveSupport::TestCase
  class DummyModel
    include ActiveModel::Validations
    attr_accessor :document

    validates_with DocumentValidator

    def initialize(document = nil)
      @document = document
    end
  end

  class DummyAttachment
    attr_accessor :content_type

    def initialize(content_type)
      @content_type = content_type
    end

    def attached?
      true
    end
  end

  test "valid with PDF content type" do
    attachment = DummyAttachment.new("application/pdf")
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "valid with JPEG content type" do
    attachment = DummyAttachment.new("image/jpeg")
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "valid with PNG content type" do
    attachment = DummyAttachment.new("image/png")
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "invalid with unsupported content type" do
    attachment = DummyAttachment.new("application/msword")
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be a PDF, JPEG, or PNG file"
  end

  test "invalid with text file content type" do
    attachment = DummyAttachment.new("text/plain")
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be a PDF, JPEG, or PNG file"
  end

  test "valid when document is not attached" do
    attachment = OpenStruct.new(attached?: false, content_type: "application/pdf")
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "valid when document is nil" do
    model = DummyModel.new(nil)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "ALLOWED_TYPES constant includes expected types" do
    assert_equal %w[application/pdf image/jpeg image/png], DocumentValidator::ALLOWED_TYPES
  end
end
