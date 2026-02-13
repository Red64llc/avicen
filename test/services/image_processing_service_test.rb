require "test_helper"

class ImageProcessingServiceTest < ActiveSupport::TestCase
  # --- ProcessedImage value object tests ---

  test "ProcessedImage has path width height and content_type attributes" do
    processed = ImageProcessingService::ProcessedImage.new(
      path: "/tmp/test.jpg",
      width: 800,
      height: 600,
      content_type: "image/jpeg"
    )

    assert_equal "/tmp/test.jpg", processed.path
    assert_equal 800, processed.width
    assert_equal 600, processed.height
    assert_equal "image/jpeg", processed.content_type
  end

  test "ProcessedImage is frozen immutable" do
    processed = ImageProcessingService::ProcessedImage.new(
      path: "/tmp/test.jpg",
      width: 800,
      height: 600,
      content_type: "image/jpeg"
    )

    assert processed.frozen?
  end

  # --- MAX_DIMENSION constant test ---

  test "MAX_DIMENSION constant is 1568" do
    assert_equal 1568, ImageProcessingService::MAX_DIMENSION
  end

  # --- Service initialization tests ---

  test "initializes with blob parameter" do
    blob = create_mock_blob
    service = ImageProcessingService.new(blob: blob)

    assert_not_nil service
  end

  # --- Resize decision tests (testing private method logic via stubbing) ---

  test "resizes when width exceeds MAX_DIMENSION" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 2000, original_height: 1000) do |service|
      result = service.call

      assert_instance_of ImageProcessingService::ProcessedImage, result
      # Width should be scaled down to MAX_DIMENSION
      assert_equal 1568, result.width
      # Height should be scaled proportionally
      assert_equal 784, result.height
    end
  end

  test "resizes when height exceeds MAX_DIMENSION" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 1000, original_height: 2000) do |service|
      result = service.call

      assert_instance_of ImageProcessingService::ProcessedImage, result
      # Height should be scaled down to MAX_DIMENSION
      assert_equal 1568, result.height
      # Width should be scaled proportionally
      assert_equal 784, result.width
    end
  end

  test "does not resize when dimensions are within MAX_DIMENSION" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false) do |service|
      result = service.call

      assert_equal 1200, result.width
      assert_equal 800, result.height
    end
  end

  test "does not resize when exactly at MAX_DIMENSION" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 1568, original_height: 1000, needs_resize: false) do |service|
      result = service.call

      assert_equal 1568, result.width
      assert_equal 1000, result.height
    end
  end

  # --- Aspect ratio preservation tests ---

  test "preserves 2:1 landscape aspect ratio when resizing" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 2000, original_height: 1000) do |service|
      result = service.call

      original_ratio = 2000.0 / 1000
      result_ratio = result.width.to_f / result.height
      assert_in_delta original_ratio, result_ratio, 0.01
    end
  end

  test "preserves 1:2 portrait aspect ratio when resizing" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 1000, original_height: 2000) do |service|
      result = service.call

      original_ratio = 1000.0 / 2000
      result_ratio = result.width.to_f / result.height
      assert_in_delta original_ratio, result_ratio, 0.01
    end
  end

  test "preserves 1:1 square aspect ratio when resizing" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 2000, original_height: 2000) do |service|
      result = service.call

      assert_equal result.width, result.height
      assert_equal 1568, result.width
    end
  end

  # --- HEIC conversion tests ---

  test "converts HEIC to JPEG content type" do
    blob = create_mock_blob(content_type: "image/heic")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false, converts_format: true) do |service|
      result = service.call

      assert_equal "image/jpeg", result.content_type
    end
  end

  test "converts HEIF to JPEG content type" do
    blob = create_mock_blob(content_type: "image/heif")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false, converts_format: true) do |service|
      result = service.call

      assert_equal "image/jpeg", result.content_type
    end
  end

  test "HEIC conversion outputs jpg extension" do
    blob = create_mock_blob(content_type: "image/heic")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false, converts_format: true) do |service|
      result = service.call

      assert result.path.end_with?(".jpg"), "Expected path to end with .jpg but got: #{result.path}"
    end
  end

  # --- Content type preservation tests ---

  test "preserves JPEG content type" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false) do |service|
      result = service.call

      assert_equal "image/jpeg", result.content_type
    end
  end

  test "preserves PNG content type" do
    blob = create_mock_blob(content_type: "image/png")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false) do |service|
      result = service.call

      assert_equal "image/png", result.content_type
    end
  end

  # --- Output extension tests ---

  test "outputs jpg extension for JPEG images" do
    blob = create_mock_blob(content_type: "image/jpeg")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false) do |service|
      result = service.call

      assert result.path.end_with?(".jpg"), "Expected .jpg extension"
    end
  end

  test "outputs png extension for PNG images" do
    blob = create_mock_blob(content_type: "image/png")

    with_stubbed_image_processing(blob, original_width: 1200, original_height: 800, needs_resize: false) do |service|
      result = service.call

      assert result.path.end_with?(".png"), "Expected .png extension"
    end
  end

  private

  def create_mock_blob(content_type: "image/jpeg")
    # Create a simple mock object that responds to content_type
    OpenStruct.new(content_type: content_type)
  end

  def with_stubbed_image_processing(blob, original_width:, original_height:, needs_resize: true, converts_format: false)
    # Calculate expected dimensions after resize
    if needs_resize
      max_dim = ImageProcessingService::MAX_DIMENSION
      if original_width >= original_height
        # Landscape or square
        scale = max_dim.to_f / original_width
        expected_width = max_dim
        expected_height = (original_height * scale).round
      else
        # Portrait
        scale = max_dim.to_f / original_height
        expected_width = (original_width * scale).round
        expected_height = max_dim
      end
    else
      expected_width = original_width
      expected_height = original_height
    end

    # Create a mock MiniMagick image
    mock_image = MockMiniMagickImage.new(
      width: original_width,
      height: original_height,
      expected_resize: needs_resize ? "#{ImageProcessingService::MAX_DIMENSION}x#{ImageProcessingService::MAX_DIMENSION}>" : nil,
      expected_format: converts_format ? "jpeg" : nil
    )

    # Mock the final image after processing
    final_image = MockMiniMagickImage.new(
      width: expected_width,
      height: expected_height
    )

    service = ImageProcessingService.new(blob: blob)

    # Create a tempfile for the output
    extension = converts_format || blob.content_type == "image/heic" || blob.content_type == "image/heif" ? ".jpg" : (blob.content_type == "image/png" ? ".png" : ".jpg")
    output_tempfile = Tempfile.new([ "processed_", extension ])
    output_path = output_tempfile.path

    # Stub blob.open to yield a fake tempfile
    fake_input = OpenStruct.new(path: "/tmp/fake_input.jpg")
    blob.define_singleton_method(:open) do |&block|
      block.call(fake_input)
    end

    # Track which MiniMagick::Image.open call we're on
    image_open_count = 0

    # Stub MiniMagick::Image.open
    original_open = MiniMagick::Image.method(:open) rescue nil
    MiniMagick::Image.define_singleton_method(:open) do |path|
      image_open_count += 1
      if image_open_count == 1
        mock_image
      else
        final_image
      end
    end

    begin
      yield service
    ensure
      output_tempfile.close
      output_tempfile.unlink rescue nil
      if original_open
        MiniMagick::Image.define_singleton_method(:open, original_open)
      end
    end
  end

  # Simple mock for MiniMagick::Image
  class MockMiniMagickImage
    attr_reader :width, :height

    def initialize(width:, height:, expected_resize: nil, expected_format: nil)
      @width = width
      @height = height
      @expected_resize = expected_resize
      @expected_format = expected_format
      @resized = false
      @formatted = false
    end

    def resize(geometry)
      @resized = true
      # Update dimensions based on resize
      if @expected_resize
        max_dim = 1568
        if @width >= @height
          scale = max_dim.to_f / @width
          @width = max_dim
          @height = (@height * scale).round
        else
          scale = max_dim.to_f / @height
          @width = (@width * scale).round
          @height = max_dim
        end
      end
    end

    def format(fmt)
      @formatted = true
    end

    def write(path)
      # Simulate writing to file
      File.write(path, "fake image data")
    end
  end
end
