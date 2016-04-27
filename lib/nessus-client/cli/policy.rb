module NessusCLI
  module Commands
    class Policy < NessusCLI::Base
  
      desc "policy list", "List all policies you can access"
      method_option :columns, :aliases => '-c', :type => :array, :default => %w(id name owner visibility), :desc => 'List of columns to display in a table'
      self.common_options
      def list
        client = self.class.client(options[:home])
        result = client.get('/policies')
        # Protect against empty results.
        result['policies'] ||= []
        self.class.table_for(result['policies'], options['columns'], "Policies") do |scan|
          options['columns'].map { |column| (column.match('date') && scan[column].is_a?(Integer)) ? Time.at(scan[column]).to_s : scan[column] }
        end
        if result['policies'].length > 0
          columns = result['policies'].first.keys
          say("Available columns:\n" + columns.join(', '))
        end
      end

      desc "policy copy POLICY_ID", "Copy a policy (you will own the new one)"
      method_option :default_permission, :banner => 'PERM', :default => 'use', :desc => 'Default permission for other users. One of "none", "use", "edit"'
      self.common_options
      def copy(policy_id)
        unless ["none", "use", "edit"].include?(options[:default_permission])
          fail('Invalid default permission.')
        end
        client = self.class.client(options[:home])
        result = client.post("/policies/#{policy_id}/copy", '')
        say("New policy:\n#{JSON.pretty_generate(result)}")
        # Also set the new policy to be usable by everyone by default.
        # 0 = 'No access'
        # 16 = 'Can use'
        # 32 = 'Can edit'
        map = { 'none' => 0, 'use' => 16, 'edit' => 32 }
        body = client.get("/permissions/policy/#{result['id']}")
        body['acls'].each do |perm|
          perm["permissions"] = map[options[:default_permission]] if perm["type"] == "default"
        end
        client.put("/permissions/policy/#{result['id']}", body)
        say('Set the default permissions so everyone can use this policy')
      end
    end
  end
end
