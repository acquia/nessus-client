require 'excon'
require 'json'

class NessusClient

  autoload :Session, "nessus-client/session"

  attr_reader :url

  # @param [String] nessus_url
  def initialize(nessus_url, access_key, secret_key)
    @url = nessus_url
    @access_key = access_key
    @secret_key = secret_key
  end

  def get(path, params = {})
   options = {}
   if params.length > 0
     options[:query] = params.to_h
   end
   options[:idempotent] = true
   request('GET', path, options)
  end

  def request(method, path, options = {})
    connection = Excon.new(url)
    options[:method] = method
    options[:path] = path
    options[:headers] ||= {}
    options[:headers] = {
      'X-ApiKeys' => "accessKey=#{@access_key}; secretKey=#{@secret_key}",
      'Content-Type' => 'application/json',
    }.merge(options[:headers])
    if options[:body] && !options[:body].instance_of?(String)
      options[:body] = options[:body].to_json
    end
    response = connection.request(options)
    if response.body.length > 0
      JSON.parse(response.body)
    end
  end
end
