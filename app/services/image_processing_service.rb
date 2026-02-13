# Image processing service for Claude Vision API optimization
#
# Resizes images to optimal dimensions for Claude Vision API (max 1568px in largest dimension)
# and converts HEIC/HEIF formats to JPEG for API compatibility.
#
# Usage:
#   service = ImageProcessingService.new(blob: active_storage_blob)
#   result = service.call
#   result.path        # => "/tmp/processed_image123.jpg"
#   result.width       # => 1568
#   result.height      # => 1045
#   result.content_type # => "image/jpeg"
#
class ImageProcessingService
  MAX_DIMENSION = 1568

  # Immutable value object for processed image result
  class ProcessedImage
    attr_reader :path, :width, :height, :content_type

    def initialize(path:, width:, height:, content_type:)
      @path = path
      @width = width
      @height = height
      @content_type = content_type
      freeze
    end
  end

  def initialize(blob:)
    @blob = blob
  end

  def call
    download_and_process
  end

  private

  attr_reader :blob

  def download_and_process
    blob.open do |tempfile|
      image = MiniMagick::Image.open(tempfile.path)
      process_image(image)
    end
  end

  def process_image(image)
    original_width = image.width
    original_height = image.height
    needs_resize = requires_resize?(original_width, original_height)
    needs_conversion = requires_format_conversion?

    if needs_resize
      resize_image(image)
    end

    output_path = generate_output_path
    output_content_type = determine_output_content_type

    if needs_conversion
      convert_to_jpeg(image, output_path)
    else
      write_image(image, output_path)
    end

    # Re-read the processed image to get accurate final dimensions
    processed = MiniMagick::Image.open(output_path)

    ProcessedImage.new(
      path: output_path,
      width: processed.width,
      height: processed.height,
      content_type: output_content_type
    )
  end

  def requires_resize?(width, height)
    width > MAX_DIMENSION || height > MAX_DIMENSION
  end

  def requires_format_conversion?
    heic_content_types.include?(blob.content_type)
  end

  def heic_content_types
    %w[image/heic image/heif]
  end

  def resize_image(image)
    # Resize to fit within MAX_DIMENSION while preserving aspect ratio
    image.resize "#{MAX_DIMENSION}x#{MAX_DIMENSION}>"
  end

  def convert_to_jpeg(image, output_path)
    image.format "jpeg"
    image.write output_path
  end

  def write_image(image, output_path)
    image.write output_path
  end

  def generate_output_path
    extension = output_extension
    tempfile = Tempfile.new([ "processed_image_", extension ])
    tempfile.close
    tempfile.path
  end

  def output_extension
    if requires_format_conversion?
      ".jpg"
    else
      extension_for_content_type(blob.content_type)
    end
  end

  def extension_for_content_type(content_type)
    case content_type
    when "image/jpeg"
      ".jpg"
    when "image/png"
      ".png"
    when "image/gif"
      ".gif"
    when "image/webp"
      ".webp"
    else
      ".jpg"
    end
  end

  def determine_output_content_type
    if requires_format_conversion?
      "image/jpeg"
    else
      blob.content_type
    end
  end
end
