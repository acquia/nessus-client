module NessusCLI
  module Commands
    class Policy < NessusCLI::Base
  
      desc "policy list", "List scans since a given date"
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
    end
  end
end