require 'excon'
require 'json'

class NessusClient

  # This class should be used to get an access token
  # for use with the main client class.
  class Session

    @token
    @url

    def self.create(url, username, password)
      payload = {
        username: username,
        password: password,
      }
      response = request('POST', url, '/session', payload)
      if response['token']
         return self.new(url, response['token'])
      else
        raise "Response did not include a session token."
      end
    end

    def self.request(method, url, path, payload = nil, headers = {})
      headers = {
        'Content-Type' => 'application/json',
      }.merge(headers)
      connection = Excon.new(url)
      body = payload ? payload.to_json : ''
      response = connection.request(method: method, path: path, body: body, headers: headers, idempotent: true, expects: [200, 201])
      if response.body.length > 0
        JSON.parse(response.body)
      end
    end

    def initialize(url, token)
      @url = url
      @token = token
    end

    def keys
       headers = {'X-Cookie' => 'token=' + @token}
       self.class.request('PUT', @url, '/session/keys', nil, headers)
    end

    def destroy
       headers = {'X-Cookie' => 'token=' + @token}
       response = self.class.request('DELETE', @url, '/session', nil, headers)
       @token = nil
    end
  end
end
