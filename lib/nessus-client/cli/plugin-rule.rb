module NessusCLI
  module Commands
    class PluginRule < NessusCLI::Base

      desc "list", "List plugin rules"
      method_option :columns, :aliases => '-c', :type => :array, :default => ['id', 'plugin_id', 'type', 'owner'], :desc => 'List of columns to display in a table'
      self.common_options
      def list
        client = self.class.client(options[:home])
        result = client.get("/plugin-rules")
        print_result_table(result["plugin_rules"], options[:columns], 'Plugin Rules')
      end

      desc "create PLUGIN_ID SEVERITY", "Create a plugin rule with new severity to apply (critical, high, medium, low, info, exclude)"
      method_option :expires, :desc => 'Expiration date for the plugin rule'
      self.common_options
      def create(plugin_id, severity)
        client = self.class.client(options[:home])
        map = {
          'critical' => 'recast_critical',
          'high' => 'recast_high',
          'medium' => 'recast_medium',
          'low' => 'recast_low',
          'info' => 'recast_info',
          'exclude' => 'exclude',
        }
        fail("Invalid severity value #{severity}") unless map[severity]
        body = {
          'plugin_id' => plugin_id,
          'type' => map[severity],
          'host' => '', # Empty means all hosts.
        }
        if options[:expires]
           date = DateTime.parse(options[:expires]).to_time.to_i
          body['date'] = date
        end
        result = client.post("/plugin-rules", body)
        say("Rule created for plugin #{plugin_id}")
      end

      desc "delete", "Delete plugin rule"
      self.common_options
      def delete(rule_id)
        client = self.class.client(options[:home])
        result = client.delete("/plugin-rules/#{rule_id}")
        say("Rule #{rule_id} deleted")
      end
    end
  end
end
