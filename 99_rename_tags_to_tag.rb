require 'yaml'

Dir.glob('../02_isbn/**/*.yml').each do |yml_path|
  metadata = YAML.load(File.read(yml_path))
  tag = metadata['tags'].first

  tag = nil if tag == 'エメさん'
  tag = nil if tag == 'ISBN'
  tag = nil if tag == 'Download'
  tag = nil if tag == '自炊の窓'
  tag = '小説' if tag == '近代小説'

  metadata.delete('tags')
  metadata['tag'] = tag
  File.write(yml_path, YAML.dump(metadata))
end
