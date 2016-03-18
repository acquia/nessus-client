require 'thor'
require 'json'

class NessusClient

  autoload :Session, "nessus-client/session"


  attr_reader :url

  # @param [String] nessus_url
  def initialize(nessus_url)
    @url = nessus_url
  end
end
