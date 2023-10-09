require "yaml"

class String
  def get_match(regex)
    if self =~ regex
      if $1
        $1
      else
        raise "No Regex pattern cache. :" + regex.to_s
      end
    else
      raise "Didn't match: " + self
    end
  end
end

Dir.glob("../original/**/*.pdf").shuffle.each do |pdf_path|
  ln_name = nil
  ln_tags = []
  pdf_yml_path = pdf_path + ".yml"
  pdf_yml = nil
  if File.exists?(pdf_yml_path)
    pdf_yml = YAML.load_file(pdf_yml_path)
    ln_tags = pdf_yml["tags"]
  end
  if pdf_yml && pdf_yml["title"] && pdf_yml["authors"] && !pdf_yml["authors"].empty?
    ln_name = "[#{pdf_yml["authors"].join(",")}#{pdf_yml["translator"] ? "（#{pdf_yml["translator"]}）" : nil}]#{pdf_yml["title"]}"
  else
    case pdf_path
    when /\/by_hand\//
      raise pdf_path
    when /\/isbn13\//, /\/magazine\//
      isbn_or_jan = pdf_path.get_match(/\/(\d+)(:?_\d)?\.pdf$/)
      aws_info_path = "../original/aws_meta/#{isbn_or_jan}.yml"
      item = nil
      if File.exists?(aws_info_path)
        aws_info = YAML.load_file(aws_info_path)
        item = aws_info["Items"]["Item"]
      end
      if item
        if item.is_a?(Array)
          item = item.find{|it| it["ItemAttributes"]["Binding"] !~ /Kindle/}
        end
        item_attr = item["ItemAttributes"]
        author = item_attr["Author"] || item_attr["Studio"]
        if author.is_a?(Array)
          author = author.join(",")
        end
        author && author.gsub!(/([^a-zA-Z])\s([^a-zA-Z])/, "\\1\\2")
        title = item_attr["Title"]
        ln_name = "[#{author}]#{title}"
        ln_tags << item_attr["Binding"].gsub(/（.+）/, "").gsub("コミック", "漫画")
      else
        ln_name = isbn_or_jan
      end
    when /\/no_isbn\//
      ln_name = pdf_path.get_match(/\/([^\/]+)\.pdf$/)
    else
      raise pdf_path
    end
  end
  if ln_tags.empty?
    ln_tags << "未整理"
  end
  ln_tags.uniq.each do |tag|
    dir_path = "../output/#{tag}"
    if !Dir.exists?(dir_path)
      Dir.mkdir(dir_path)
    end
    ln_name_clean = ln_name.gsub(/[\\\/\:\*\?\<\>\"\|]/, "_").tr("０-９Ａ-Ｚａ-ｚ（）", "0-9A-Za-z()")
    ln_path = "#{dir_path}/#{ln_name_clean}.pdf"
    while File.exists?(ln_path)
      if ln_path !~ /_(\d+)\.pdf$/
        ln_path.gsub!(/\.pdf$/, "_1.pdf")
      end
      i = $1.to_i
      ln_path.gsub!(/\_#{i}\.pdf$/, "_#{i + 1}.pdf")
    end
    puts pdf_path + " : " + ln_path
    p `ln -s ../#{pdf_path} \"#{ln_path}\"`
  end
end
