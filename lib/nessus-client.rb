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

  def get(path, query = {})
   options = {}
   options[:query] = query.to_h if query.length > 0
   options[:idempotent] = true
   json_request('GET', path, options)
  end

  def json_request(method, path, options = {})
    if options[:body] && !options[:body].instance_of?(String)
      options[:body] = options[:body].to_json
    end
    options[:headers] ||= {}
    options[:headers]['Content-Type'] = 'application/json'
    response = request(method, path, options)
    JSON.parse(response.body) if (response.body.length > 0 && response.headers['content-type'].match(/json/))
  end

  def request(method, path, options = {})
    connection = Excon.new(url)
    options[:method] = method
    options[:path] = path
    options[:headers] ||= {}
    options[:headers]['X-ApiKeys'] = "accessKey=#{@access_key}; secretKey=#{@secret_key}"
    connection.request(options)
  end

  def download_report
  end

  # Exception thrown when a retry times out
  class TimeoutException < RuntimeError
  end

  # Retry a block of code multiple times until it returns true, or until
  # time limit ais reached. This always runs the block at least once.
  #
  # Options:
  #
  #  [:delay]  Sleep the given number of seconds between each try.
  #            The default to sleep 2 seconds.
  #
  #  [:timeout] Don't try for longer than the given number of seconds.
  #
  #  [:message] A message that describes what is being attempted.
  #
  #  [:stdout] An IO object to write messages to. Defaults to $stdout.
  #
  def self.retry(opts = {}, &blk)
    opts = {
      delay: 2,
      timeout: 30,
      stdout: $stdout,
    }.merge(opts)

    d = opts[:delay]
    io = opts[:stdout]
    times = 0
    start_time = Time.now.to_f
    stop_time = Time.now.to_i + opts[:timeout]
    io.puts "Waiting for: #{opts[:message]}" if opts[:message]
    begin
      sleep(d) if times > 0
      times += 1
      result = blk.call(times)
      if (!result) &&(Time.now.to_f - start_time) >= opts[:timeout]
        raise TimeoutException.new("Timeout after #{opts[:timeout]} sec.")
      end
      io.puts "+ retry: #{stop_time-Time.now.to_i} secs left"
    end while (!result)
    result
  end
end
