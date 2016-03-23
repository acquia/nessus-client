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

  # Make a GET request expecting a JSON response.
  def get(path, query = {}, options = {})
   options[:query] = query.to_h if query.length > 0
   options[:idempotent] = true
   json_request('GET', path, options)
  end

  # Make a POST request expecting a JSON response.
  def post(path, body, query = {}, options = {})
   options[:query] = query.to_h if query.length > 0
   options[:body] = body
   json_request('POST', path, options)
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
    options[:expects] ||= [200]
    options[:method] = method
    options[:path] = path
    options[:headers] ||= {}
    options[:headers]['X-ApiKeys'] = "accessKey=#{@access_key}; secretKey=#{@secret_key}"
    connection.request(options)
  end

  # Export and download a scan result
  #
  # @return String
  #   The filepath of the file that was downloaded.
  def export_download_scan(scan_id, params = {}, download_directory = '')
    params = {
      'format' => 'pdf',
      'chapters' => ['vuln_hosts_summary'],
    }.merge(params)
    fail 'Invalid format' unless ['csv', 'db', 'html', 'pdf'].include?(params['format'])
    data = post("/scans/#{scan_id}/export", params)
    file_id = data['file']
    fail "Invalid response to export" unless file_id
    self.retry do
      data = get("/scans/#{scan_id}/export/#{file_id}/status")
      data['status'] == 'ready'
    end
    # Use request() since we the response is a file, not JSON
    response = request('GET', "/scans/#{scan_id}/export/#{file_id}/download")
    match = response.headers['content-disposition'].match(/attachment; filename="([^"]+)"/)
    fail 'Invalid download response' unless match
    target_filename = File.join(download_directory, match[1])
    bytes = File.write(target_filename, response.data)
    fail "File has wrong number of bytes #{target_filename}" unless bytes.to_i == response.headers['content-length'].to_i
    target_filename
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
