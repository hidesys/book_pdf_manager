require 'net/http'
require 'uri'
require 'open-uri'

module OpenAI
  COMPLETION_API_ENDPOINT = 'https://api.openai.com/v1/completions'.freeze
  def query(prompt)
    uri = URI.parse(COMPLETION_API_ENDPOINT)
    query = {
      model: 'text-davinci-003',
      temperature: 0,
      prompt:
    }
    response = Net::HTTP.post(uri, query.to_json, headers)
    body = response.body.to_s
    choices = JSON.parse(body)['choices']
    raise body if choices.nil?

    choices.map { |choice| choice['text'].strip }.join
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV.fetch('OPENAI_API_KEY', nil)}"
    }
  end

  module_function :query, :headers
end
