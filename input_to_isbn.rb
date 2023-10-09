require "yaml"

INPUT_GLOB = "../01_input/**/*.pdf"
OUTPUT_DIR = "../02_isbn"

puts "Start."
file_list = Dir.glob(INPUT_GLOB).sort
file_list.each.with_index do |input_path, file_index|
  puts "Process (#{file_index + 1}/#{file_list.length}): #{input_path}"
  #カバーを取り出す
  if `pdfimages -list \"#{input_path}\"`.split("\n").last !~ /^\s*(\d+)\s/
    next
  end
  `pdfimages -f #{$1} -j \"#{input_path}\" ./`
  cover_path = Dir.glob("./*.jpg").first
  cover_path ||= Dir.glob("./*.ppm").first
  cover_path ||= Dir.glob("./*.pbm").first
  cover_ext = cover_path.split(".").last
  cover_temp_name = "input.#{cover_ext}"
  File.rename(cover_path, cover_temp_name)
  zbars = `zbarimg -q #{cover_temp_name}`.split("\n").map{|zbar| zbar =~ /\:(\d+)$/ ? $1 : nil}.compact
  File.delete(cover_temp_name)
  #メタデータ処理
  isbn13 = zbars.find{|zbar| zbar =~ /^(97[89]\d+)$/}
  magazine_code = zbars.find{|zbar| zbar =~ /^(491\d+)$/}
  original_file_path = input_path =~ /^\.\.\/01_input\/(.+)$/ && $1
  tag = original_file_path =~ /^(.+?)\// && $1
  original_file_name = original_file_path.split("/").last
  author = original_file_name =~ /^\[(.+?)(（.+）)?\]/ && $1
  translater = $2 && $2[1..-2]
  title = original_file_name =~ /\](.+?)(（OCR済）)?\.pdf$/i && $1
  ocr = $2
  volume = title ? (title =~ /^.+?(\d+)$/ ? $1.to_i : nil) : nil
  if isbn13
    output_path = "#{OUTPUT_DIR}/isbn13/#{ocr ? nil : "un_ocr/"}#{isbn13}.pdf"
  elsif magazine_code
    output_path = "#{OUTPUT_DIR}/magazine/#{ocr ? nil : "un_ocr/"}#{magazine_code}.pdf"
  elsif author && title
    output_path = "#{OUTPUT_DIR}/title_by_hand/#{ocr ? nil : "un_ocr/"}[#{author}#{translater ? "（#{translater}）" : nil}]#{title}.pdf"
  else
    output_path = "#{OUTPUT_DIR}/no_isbn_no_title/#{ocr ? nil : "un_ocr/"}#{original_file_name}"
  end
  while File.exists?(output_path)
    if output_path !~ /_(\d+)\.pdf$/
      output_path.gsub!(/\.pdf$/, "_1.pdf")
    end
    i = $1.to_i
    output_path.gsub!(/\_#{i}\.pdf$/, "_#{i + 1}.pdf")
  end
  puts "  move to: #{output_path}"
  meta = {
    "zbars" => zbars,
    "isbn13" => isbn13,
    "magazine_code" => magazine_code,
    "original_file_path" => original_file_path,
    "tags" => (tag ? [tag] : []),
    "original_file_name" => original_file_name,
    "author" => author,
    "translater" => translater,
    "title" => title,
    "ocr" => !!ocr,
    "volume" => volume
  }
  File.open(output_path + ".yml", "w") do |f|
    f.write meta.to_yaml
  end
  File.rename(input_path, output_path)
end
puts "Finish."
