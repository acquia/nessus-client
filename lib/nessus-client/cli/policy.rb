module NessusCLI
  module Commands
    class Policy < NessusCLI::Base

      # @return [Hash]
      def self.policy_permissions
        { 'none' => 0, 'use' => 16, 'edit' => 32 }
      end

      # @param [String] name
      #
      # @return [Int] numeric permission
      def self.map_policy_permission(name)
        map = policy_permissions
        fail("Invalid permission '#{name}'.") unless map[name]
        map[name]
      end

      desc "list", "List all policies you can access"
      method_option :columns, :aliases => '-c', :type => :array, :default => %w(id name owner visibility), :desc => 'List of columns to display in a table'
      self.common_options
      def list
        client = self.class.client(options[:home])
        result = client.get('/policies')
        print_result_table(result['policies'], options[:columns], 'Policies')
      end

      desc "copy POLICY_ID", "Copy a policy (you will own the new one)"
      method_option :default_permission, :banner => 'PERM', :default => 'use', :desc => 'Default permission for other users. One of ' + self.policy_permissions.keys.inspect
      self.common_options
      def copy(policy_id)
        int_default_perm = self.class.map_policy_permission(options[:default_permission])
        client = self.class.client(options[:home])
        result = client.post("/policies/#{policy_id}/copy", '')
        say("New policy:\n#{JSON.pretty_generate(result)}")
        # Also set the new policy to be usable by everyone by default.
        body = client.get("/permissions/policy/#{result['id']}")
        body['acls'].each do |perm|
          perm["permissions"] = int_default_perm if perm["type"] == "default"
        end
        client.put("/permissions/policy/#{result['id']}", body)
        permission_message('policy', options[:default_permission])
      end

      desc "set-default-permission POLICY_ID", "Set default permissions for a policy"
      method_option :default_permission, :banner => 'PERM', :default => 'use', :desc => 'Default permission for other users. One of ' + self.policy_permissions.keys.inspect
      self.common_options
      def set_default_permission(policy_id)
        int_default_perm = self.class.map_policy_permission(options[:default_permission])
        client = self.class.client(options[:home])
        body = client.get("/permissions/policy/#{policy_id}")
        body['acls'].each do |perm|
          perm["permissions"] = int_default_perm if perm["type"] == "default"
        end
        client.put("/permissions/policy/#{policy_id}", body)
        permission_message('policy', options[:default_permission])
      end
    end
  end
end
