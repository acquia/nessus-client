module NessusCLI
  module Commands

    class Scan < NessusCLI::Base

      # @return [Hash]
      def self.scan_permissions
        { 'none' => 0, 'view' => 16, 'control' => 32, 'configure' => 64 }
      end

      # @param [String] name
      #
      # @return [Int] numeric permission
      def self.map_scan_permission(name)
        map = scan_permissions
        fail("Invalid permission '#{name}'.") unless map[name]
        map[name]
      end

      desc "list", "List scans since a given date"
      method_option :folder_id, :type => :numeric, :desc => 'Folder ID'
      method_option :since, :desc => 'Last modification date. Show only scans changed since then. Default 7 days.'
      method_option :all, :type => :boolean, :desc => 'Show all scans regardless of '
      method_option :columns, :aliases => '-c', :type => :array, :default => %w(id name status), :desc => 'List of columns to display in a table'
      self.common_options
      def list
        client = self.class.client(options[:home])
        params = {}
        if options[:since]
           since = DateTime.parse(options[:since]).to_time.to_i
        else
          # Default to 7 days ago.
          since = Time.now.to_i - (7 * 24 * 3600)
        end
        params['last_modification_date'] = since
        if options[:folder_id]
          params = options[:folder_id]
        end
        result = client.get('/scans', params)
        print_result_table(result['scans'], options[:columns], "Scans since #{Time.at(since).to_s}")
      end

      desc "update-targets SCAN_ID", "Update the targets for a scan."
      method_option :target_file, :aliases => ['-f', '--file'], :desc => 'File containing a list of target fully-qualified hostnames (one per line).'
      method_option :target_list, :aliases => ['-l', '--list'], :type => :array, :desc => 'List of space separated fully-qualified hostnames'
      self.common_options
      def update_targets(scan_id)
        fail('Please supply --target-file or --target-list') unless options[:target_file] || options[:target_list]
         client = self.class.client(options[:home])
         body = {
           'settings' => {},
         }
         if options[:target_file]
           fail("Invalid file name #{options[:target_file]}") unless File.readable?(options[:target_file])
           body['settings']['text_targets'] = File.read(options[:target_file]).split(' ').join(", ")
         elsif options[:target_list].count > 0
           body['settings']['text_targets'] = options[:target_list].join(", ")
         end
        result = client.put("/scans/#{scan_id}", body)
        say("Updated '#{result['name']}' with #{result['custom_targets'].split(',').count} targets.")
      end

      desc "launch SCAN_ID", "Launch a scan. You should normally specify targets with a list or file."
      method_option :target_file, :aliases => ['-f', '--file'], :desc => 'File containing a list of target fully-qualified hostnames (one per line).'
      method_option :target_list, :aliases => ['-l', '--list'], :type => :array, :desc => 'List of space separated fully-qualified hostnames'
      self.common_options
      def launch(scan_id)
         client = self.class.client(options[:home])
         body = {}
         if options[:target_file]
           fail("Invalid file name #{options[:target_file]}") unless File.readable?(options[:target_file])
           body['alt_targets'] = File.read(options[:target_file]).split(' ')
         elsif options[:target_list].count > 0
           body['alt_targets'] = options[:target_list]
         end
         data = client.post("/scans/#{scan_id}/launch", body)
         fail('Invalid response') unless data['scan_uuid']
         say("Scan #{scan_id} launched with histoy UUID #{data['scan_uuid']}")
      end

      desc "create POLICY_ID", "Create a scan from a policy."
      method_option :name, :required => true, :desc => 'Name for the scan.'
      method_option :description,  :desc => 'Description of the scan'
      method_option :default_permission, :banner => 'PERM', :default => 'control', :desc => 'Default permission for other users. One of ' + self.scan_permissions.keys.inspect
      self.common_options
      def create(policy_id)
         int_default_perm = self.class.map_scan_permission(options[:default_permission])
         client = self.class.client(options[:home])
         data = client.get('/policies')
         policy_id = policy_id.to_i
         policy = data['policies'].select{|pol| pol['id'] == policy_id }.first
         fail('Policy not found') unless policy
         body = {
           "uuid" => policy['template_uuid'],
           'settings' => {
             # Set default permission 32 = 'Can control'
             "acls" => [{ "permissions" => int_default_perm, "owner" => nil, "display_name" => nil, "name" => nil, "id" => nil, "type" => "default" }],
             "name" => options[:name],
             "description" => options[:description] ? options[:description] : "Scan created from policy: #{policy['name']} (#{policy_id})",
             "policy_id" => policy_id.to_i,
             "text_targets" => ' ', # Need a non-empty string.
           }
         }

         data = client.post("/scans", body)
         fail('Invalid response') unless data['scan']
         say("New scan:\n#{JSON.pretty_generate(data['scan'])}")
      end

      desc "download SCAN_ID", 'Download the most recent results for a scan identified by a numeric ID'
      method_option :chapters, :type => :array, :default => ['vuln_hosts_summary'], :desc => 'Sections to include in the report. Valid sections: vuln_hosts_summary, vuln_by_host, compliance_exec, remediations, vuln_by_plugin, compliance'
      method_option :format, :default => 'pdf', :desc => 'Available formats: pdf, nessus, html, csv, db'
      method_option :password, :desc => 'Password for db format (required only for that format)'
      method_option :history_id, :aliases => '--hist', :desc => 'History ID if you want to get something other than the most recent scan.'
      method_option :dir, :default => ENV['HOME'], :desc => 'Directory to save the downloaded file.'
      self.common_options
      def download(scan_id)
        client = self.class.client(options[:home])
        body = {
          'format' => options[:format],
          'chapters' => options[:chapters],
        }
        if options[:password]
          body['password'] = options[:password]
        end
        filename = client.export_download_scan(scan_id, body, options[:dir], options[:history_id])
        say("Scan downloaded to #{filename}")
      end

      desc "info SCAN_ID", 'More detailed information for a scan identified by a numeric ID'
      self.common_options
      def info(scan_id)
        client = self.class.client(options[:home])
        details = client.get("/scans/#{scan_id}")
        table_for(details['info'], ['Name', 'Value'], "Scan info for '#{details['info']['name']}' (#{scan_id})") do |row|
          [row[0], row[1] && row[0].match(/(timestamp|_start|_end)$/) ? Time.at(row[1]).to_s : row[1].inspect]
        end
      end

      desc "set-default-permission SCAN_ID", "Set default permissions for a scan"
      method_option :default_permission, :banner => 'PERM', :default => 'control', :desc => 'Default permission for other users. One of ' + self.scan_permissions.keys.inspect
      self.common_options
      def set_default_permission(scan_id)
        int_default_perm = self.class.map_scan_permission(options[:default_permission])
        client = self.class.client(options[:home])
        # Get current details to preserve targets, etc.
        info = client.get("/scans/#{scan_id}")['info']
        body = {
          'settings' => {
            'acls' => info['acls'],
            "text_targets" => info["targets"] || ' ',
          },
        }
        body['settings']['acls'].each do |perm|
          perm["permissions"] = int_default_perm if perm["type"] == "default"
        end
        client.put("/scans/#{scan_id}", body)
        permission_message('scan', options[:default_permission])
      end

      desc "history SCAN_ID", 'History information for a scan identified by a numeric ID'
      method_option :columns, :aliases => '-c', :type => :array, :default => %w(history_id status last_modification_date), :desc => 'List of columns to display in a table'
      self.common_options
      def history(scan_id)
        client = self.class.client(options[:home])
        details = client.get("/scans/#{scan_id}")
        table_for(details['history'], options['columns'], "Scan history for '#{details['info']['name']}' (#{scan_id})") do |scan|
          options['columns'].map { |column| (column.match('date') && scan[column].is_a?(Integer)) ? Time.at(scan[column]).to_s : scan[column] }
        end
        if details['history'].length > 0
          columns = details['history'].first.keys
          say("Available columns:\n" + columns.join(', '))
        end
      end
    end
  end
end
