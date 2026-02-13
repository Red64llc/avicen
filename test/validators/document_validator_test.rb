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

    # Default to a small file size for backward compatibility
    def byte_size
      1.megabyte
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
    assert_includes model.errors[:document], "must be a PDF, JPEG, PNG, HEIC, or HEIF file"
  end

  test "invalid with text file content type" do
    attachment = DummyAttachment.new("text/plain")
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be a PDF, JPEG, PNG, HEIC, or HEIF file"
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
    expected_types = %w[application/pdf image/jpeg image/png image/heic image/heif]
    assert_equal expected_types, DocumentValidator::ALLOWED_TYPES
  end

  # Task 2.3: HEIC and HEIF support for document scanning
  test "valid with HEIC content type" do
    attachment = DummyAttachment.new("image/heic")
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "valid with HEIF content type" do
    attachment = DummyAttachment.new("image/heif")
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  # Task 2.3: File size validation
  test "MAX_FILE_SIZE constant is 10MB" do
    assert_equal 10.megabytes, DocumentValidator::MAX_FILE_SIZE
  end

  test "valid with file under 10MB" do
    attachment = DummyAttachmentWithSize.new("application/pdf", 5.megabytes)
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "valid with file exactly 10MB" do
    attachment = DummyAttachmentWithSize.new("application/pdf", 10.megabytes)
    model = DummyModel.new(attachment)
    assert model.valid?
    assert_empty model.errors[:document]
  end

  test "invalid with file over 10MB" do
    attachment = DummyAttachmentWithSize.new("application/pdf", 11.megabytes)
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be less than 10MB"
  end

  test "invalid with large oversized file" do
    attachment = DummyAttachmentWithSize.new("application/pdf", 50.megabytes)
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be less than 10MB"
  end

  test "both content type and size are validated" do
    # Invalid type, valid size
    attachment = DummyAttachmentWithSize.new("application/msword", 5.megabytes)
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be a PDF, JPEG, PNG, HEIC, or HEIF file"
    assert_not_includes model.errors[:document], "must be less than 10MB"
  end

  test "both errors shown when type invalid and size too large" do
    attachment = DummyAttachmentWithSize.new("application/msword", 15.megabytes)
    model = DummyModel.new(attachment)
    assert_not model.valid?
    assert_includes model.errors[:document], "must be a PDF, JPEG, PNG, HEIC, or HEIF file"
    assert_includes model.errors[:document], "must be less than 10MB"
  end

  test "content type error message lists all allowed types" do
    attachment = DummyAttachment.new("text/plain")
    model = DummyModel.new(attachment)
    assert_not model.valid?
    # Updated error message includes HEIC and HEIF
    assert_includes model.errors[:document], "must be a PDF, JPEG, PNG, HEIC, or HEIF file"
  end
end

# Helper class for testing file size validation
class DummyAttachmentWithSize
  attr_accessor :content_type, :byte_size

  def initialize(content_type, byte_size)
    @content_type = content_type
    @byte_size = byte_size
  end

  def attached?
    true
  end
end
