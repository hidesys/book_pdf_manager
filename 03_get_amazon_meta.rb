require 'dotenv/load'
require 'amazon/ecs'
require 'yaml'
require 'active_support'
require 'active_support/core_ext/hash/conversions'

Amazon::Ecs.configure do |options|
  options[:AWS_access_key_id] = AWS_ACCESS_KEY
  options[:AWS_secret_key] = AWS_SECRET_ACCESS_KEY
  options[:associate_tag] = ASSOCIATE_TAG
  options[:search_index] = 'Books'
  options[:response_group] = 'Medium'
  options[:country] = 'jp'
end

isbns = Dir.glob('../original/isbn13/**/*.pdf').map do |file_path|
  file_path =~ %r{/(\d+)[_\.]} ? Regexp.last_match(1) : nil
end.uniq.compact
jans = Dir.glob('../original/magazine/**/*.pdf').map do |file_path|
  file_path =~ %r{/(\d+)[_\.]} ? Regexp.last_match(1) : nil
end.uniq.compact
(isbns + jans).each.with_index do |isbn, isbn_index|
  puts "Process (#{isbn_index + 1}/#{isbns.length + jans.length}): #{isbn}"
  file_path = "../original/aws_meta/#{isbn}.yml"
  next if File.exist?(file_path)

  retry_count = 0
  begin
    res = Amazon::Ecs.item_search(isbn)
  rescue StandardError => e
    retry_count += 1
    puts "  Retry: #{retry_count} times."
    raise e if retry_count >= 10

    sleep 10
    retry
  end
  xml = res.doc.to_s
  data = Hash.from_xml(xml)
  File.write(file_path, data['ItemSearchResponse'].to_yaml)
  puts '  Got it.'
  sleep 2
end
