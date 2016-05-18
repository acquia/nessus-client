module NessusCLI
  module Commands
    class User < NessusCLI::Base

      # @return [Hash]
      def self.policy_permissions
        { 'read-only' => 16, 'standard' => 32, 'administrator' => 64, 'system-administrator' => 128 }
      end

      # @param [String] name
      #
      # @return [Int] numeric permission
      def self.map_policy_permission(name)
        map = policy_permissions
        fail("Invalid permission '#{name}'.") unless map[name]
        map[name]
      end

      desc "list", "List all users"
      method_option :columns, :aliases => '-c', :type => :array, :default => %w(username permissions lastlogin), :desc => 'List of columns to display in a table'
      self.common_options
      def list
        client = self.class.client(options[:home])
        result = client.get('/users')
        print_result_table(result['users'], options[:columns], "Users", 'last')
      end

    end
  end
end
