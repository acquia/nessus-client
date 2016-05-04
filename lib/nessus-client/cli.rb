require 'thor'
require 'nessus-client'
require 'yaml'
require 'uri'
require 'date'
require 'terminal-table'

module NessusCLI
  class Base < Thor
  
    # Thor thinks its a good idea to not exit(1) when something bad
    # happens, like bad command line arguments.  We disagree.
    def self.exit_on_failure?
      true
    end
  
    no_commands do
  
      def self.client(home)
        creds = NessusClient::Creds::YamlFile.new(home)
        NessusClient.new(creds)
      end
  
      # @param [String] type
      #   e.g. scan or policy
      # @param [String] name
      #   Name of the permission, e.g. "none" or "edit"
      def permission_message(type, name)
        if name == 'none'
          say("Set the default permissions so only you can access this #{type}")
        else
          say("Set the default permissions so everyone can #{name} this #{type}")
        end
      end

      # Display a table to the user. The provided block should an Array of
      # row values.
      #
      # @param enum [Enumerator]
      # @param cols [Array]
      #   List of column headers.
      # @param title [String]
      #   Optional table title.
      # @yield elem [Object]
      #   The current object in the enumeration.
      # @return nil
      def self.table_for(enum, cols, title = nil)
        rows = []
        enum.each do |elem|
          rows << yield(elem)
        end
  
        puts Terminal::Table.new(
          title: title,
          headings: cols,
          rows: rows,
          style: {
            border_x: '-',
            border_y: '',
            border_i: '',
            padding_left: 0,
            padding_right: 2
          })
      end
  
      # Common workflow Thor options
      def self.common_options
        method_option :home, :type => :string, :default => ENV['HOME'], :desc => 'Home directory location for credentials file'
      end
  
      def self.common_list_options
      end
    end
  end
  
  module Commands
    autoload :Scan, 'nessus-client/cli/scan'
    autoload :Policy, 'nessus-client/cli/policy'
  end

  class Nessus < Base
    desc "get-api-key NESSUS_URL", "Use username and password (interactive prompt) to generate an API key for Nessus and save to #{NessusClient::Creds::YamlFile::FILENAME}"
    method_option :yes, :aliases => '-y', :type => :boolean, :desc => 'Skip prompts for confirmation'
    self.common_options
    def get_api_key(nessus_url)
       uri = URI(nessus_url)
       fail("You nees to use a https:// URL for Nessus") unless uri.scheme == 'https'
       creds_file = File.join(options[:home], NessusClient::Creds::YamlFile::FILENAME)
       if File.exist?(creds_file) && !options[:yes]
         confirm = ask("Overwrite existing file #{creds_file} ?", :yellow, limited_to: %w(yes no), default: 'yes')
         if confirm != 'yes'
           say("Aborting command", :red)
           exit
         end
       end
       username = ask("username:")
       password = ask("password:", :echo => false)
       say('********')
       session = NessusClient::Session.create(nessus_url, username, password)
       keys = session.keys
       keys = {'url' => nessus_url}.merge(keys)
       # Append username as comment
       creds_yaml = keys.to_yaml + "\n# API keys for #{username}\n"
       File.write(creds_file, creds_yaml)
       say("New API keys written to #{creds_file}")
       session.destroy
    end
  
    desc "scan SUMCOMMAND ...ARGS", "Scan related commands"
    subcommand 'scan', NessusCLI::Commands::Scan
  
    desc "policy SUBCOMMAND ...ARGS", "Policy related commands"
    subcommand 'policy', NessusCLI::Commands::Policy
  end
end
