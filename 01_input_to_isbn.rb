require 'yaml'

INPUT_GLOB = '../01_input/**/*.pdf'.freeze

class PdfProcessor
  OUTPUT_DIR = '../02_isbn'.freeze
  def initialize(input_path)
    @input_path = input_path
  end

  def process
    cover_temp_name = extract_cover
    return false unless cover_temp_name

    zbars = read_barcode(cover_temp_name)
    File.delete(cover_temp_name)
    metadata = generate_meta(zbars)
    output_path = generate_output_path(metadata['isbn13'], metadata['magazine_code'], metadata['author'],
                                       metadata['translater'], metadata['title'], metadata['ocr'], metadata['original_file_name'])

    puts "  move to: #{output_path}"
    YAML.dump(metadata, File.open("#{output_path}.yml", 'w'))
    File.rename(@input_path, output_path)
  end

  private

  def extract_cover
    last_page = `pdfimages -list \"#{@input_path}\"`.split("\n").last
    return false if last_page !~ /^\s*(\d+)\s/

    `pdfimages -f #{::Regexp.last_match(1)} -j \"#{@input_path}\" ./tmp/`
    cover_path = Dir.glob('./tmp/*.jpg').first
    cover_path ||= Dir.glob('./tmp/*.ppm').first
    cover_path ||= Dir.glob('./tmp/*.pbm').first
    cover_ext = cover_path.split('.').last
    cover_temp_name = "./tmp/input.#{cover_ext}"
    File.rename(cover_path, cover_temp_name)
    cover_temp_name
  end

  def read_barcode(cover_temp_name)
    `zbarimg -q #{cover_temp_name}`.split("\n").map { |zbar| zbar =~ /:(\d+)$/ ? ::Regexp.last_match(1) : nil }.compact
  end

  def generate_meta(zbars)
    # メタデータ処理
    isbn13 = zbars.find { |zbar| zbar =~ /^(97[89]\d+)$/ }
    magazine_code = zbars.find { |zbar| zbar =~ /^(491\d+)$/ }
    original_file_path = @input_path =~ %r{^\.\./01_input/(.+)$} && ::Regexp.last_match(1)
    tag = original_file_path =~ %r{^(.+?)/} && ::Regexp.last_match(1)
    original_file_name = original_file_path.split('/').last
    author = original_file_name =~ /^\[(.+?)(（.+）)?\]/ && ::Regexp.last_match(1)
    translater = ::Regexp.last_match(2) && ::Regexp.last_match(2)[1..-2]
    title = original_file_name =~ /\](.+?)(（OCR済）)?\.pdf$/i && ::Regexp.last_match(1)
    ocr = ::Regexp.last_match(2)
    volume = if title
               title =~ /^.+?(\d+)$/ ? ::Regexp.last_match(1).to_i : nil
             end
    {
      'zbars' => zbars,
      'isbn13' => isbn13,
      'magazine_code' => magazine_code,
      'original_file_path' => original_file_path,
      'tag' => tag,
      'original_file_name' => original_file_name,
      'author' => author,
      'translater' => translater,
      'title' => title,
      'ocr' => !ocr.nil?,
      'volume' => volume
    }
  end

  def generate_output_path(isbn13, magazine_code, author, translater, title, ocr, original_file_name)
    output_path = nil
    if isbn13
      output_path = "#{OUTPUT_DIR}/isbn13/#{ocr ? 'ocred' : 'un_ocr/'}#{isbn13}.pdf"
    elsif magazine_code
      output_path = "#{OUTPUT_DIR}/magazine/#{ocr ? 'ocred' : 'un_ocr/'}#{magazine_code}.pdf"
    elsif author && title
      output_path = "#{OUTPUT_DIR}/title_by_hand/#{ocr ? 'ocred' : 'un_ocr/'}[#{author}#{translater ? "（#{translater}）" : nil}]#{title}.pdf"
    else
      output_path = "#{OUTPUT_DIR}/no_isbn_no_title/#{ocr ? 'ocred' : 'un_ocr/'}#{original_file_name}"
    end
    while File.exist?(output_path)
      output_path.gsub!(/\.pdf$/, '_1.pdf') if output_path !~ /_(\d+)\.pdf$/
      i = ::Regexp.last_match(1).to_i
      output_path.gsub!(/_#{i}\.pdf$/, "_#{i + 1}.pdf")
    end
    output_path
  end
end

puts 'Start.'
file_list = Dir.glob(INPUT_GLOB)
file_list.each.with_index do |input_path, file_index|
  puts "Process (#{file_index + 1}/#{file_list.length}): #{input_path}"
  PdfProcessor.new(input_path).process
end
puts 'Finish.'
