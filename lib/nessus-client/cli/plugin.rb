module NessusCLI
  module Commands
    class Plugin < NessusCLI::Base

      desc "families", "List all plugin families"
      self.common_options
      def families
        client = self.class.client(options[:home])
        result = client.get('/plugins/families')
        print_result_table(result['families'], ['id', 'name', 'count'], "Plugin families")
      end

      desc "family-details FAMILY_ID", "List all plugins in a family"
      self.common_options
      def family_details(family_id)
        client = self.class.client(options[:home])
        result = client.get("/plugins/families/#{family_id}")
        result["plugins"] ||= []
        table_for(result["plugins"], ['id', 'name'], "Pugin family: #{result['name']}") do |r|
          [ r["id"], r["name"] ]
        end
      end

      desc "details PLUGIN_ID", "Get plugin details"
      self.common_options
      def details(plugin_id)
        client = self.class.client(options[:home])
        result = client.get("/plugins/plugin/#{plugin_id}")
        say("#{result['name']} id: #{result['id']} family: #{result['family_name']}")
        result["attributes"] ||= []
        table_for(result["attributes"], ['Name', 'Value'], 'Attributes') do |r|
          [ r["attribute_name"], r["attribute_value"] ]
        end
      end

    end
  end
end
