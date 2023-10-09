require 'dotenv/load'
require "google/cloud/vision/v1"
require './open_a_i'
require './load_google_credential'

class GenerateTitleAndAuthor
  def initialize(pdf_file)
    @pdf_file = pdf_file
  end

  def process
    cover_path, last_page_path = extract_cover_and_last_page
    return false unless cover_path && last_page_path

    cover_texts = detect_texts(cover_path)
    last_page_texts = detect_texts(last_page_path)
    FileUtils.rm(cover_path)
    FileUtils.rm(last_page_path)

    author, title = extract_author_and_title(cover_texts, last_page_texts)
    return false unless author && title

    rename_pdf(title, author)
  end

  private

  def extract_cover_and_last_page
    last_page = `pdfimages -list \"#{@pdf_file}\"`.split("\n").last
    return false if last_page !~ /^\s*(\d+)\s/

    last_page_num = ::Regexp.last_match(1)
    `pdfimages -f 1 -l 1 -j \"#{@pdf_file}\" ./tmp/`
    cover_original_path = Dir.glob('./tmp/*.jpg').first
    cover_path = "./tmp/#{Time.now.to_i}_cover.jpg"
    FileUtils.mv(cover_original_path, cover_path)

    `pdfimages -f #{last_page_num} -j \"#{@pdf_file}\" ./tmp/`
    last_page_original_path = (Dir.glob('./tmp/*.jpg') - [cover_path]).first
    return false unless last_page_original_path
    last_page_path = "./tmp/#{Time.now.to_i}_last_page.jpg"
    FileUtils.mv(last_page_original_path, last_page_path)

    [cover_path, last_page_path]
  end

  def detect_texts(file_path)
    image_annotator = ::Google::Cloud::Vision::V1::ImageAnnotator::Client.new

    response = image_annotator.text_detection(image: file_path)
    response.responses.map do |res|
      res.text_annotations.map do |text|
        text.description
      end
    end.flatten.join(" ")
  end

  def extract_author_and_title(cover_texts, last_page_texts)
    json = { input_path: @pdf_file, cover_texts: , last_page_texts:  }.to_json
    prompt = <<~EOS
      下記のJSONファイルはPDFのファイル名と、カバーページと最終ページのOCRの結果です。中には不要なスペースが混じっています。
      このJSONから著者名と本のタイトルを、不要なスペースを除いた上で、日本語名を優先して生成し、
      1行目に著者名を、2行目にタイトルのみを入れて返してください。
      もし著者名やタイトルがわからなかった場合は「不明」と返してください。

      --
      #{json}
    EOS
    result = OpenAI.query(prompt[0..1024])
    result.split("\n").map do |line|
      line.gsub('/', '_').strip
    end
  rescue => e
    puts e
  end

  def rename_pdf(title, author)
    FileUtils.mkdir_p('../02_isbn/title_by_ai/') unless File.exist?('../02_isbn/title_by_ai/')
    new_pdf_path = "../02_isbn/title_by_ai/[#{author}]#{title}.pdf"
    puts "Renaming #{@pdf_file} to #{new_pdf_path}"
    return false if File.exist?(new_pdf_path)

    FileUtils.mv(@pdf_file, new_pdf_path)
  end
end

pdfs = Dir.glob('../02_isbn/no_isbn_no_title/**/*.pdf').sort.reverse
pdfs.each.with_index do |pdf_file, index|
  puts "processing #{pdf_file}, #{index + 1} of #{pdfs.size}"
  GenerateTitleAndAuthor.new(pdf_file).process
end
