module NessusCLI
  module Commands

    class Scan < NessusCLI::Base
      desc "scan list", "List scans since a given date"
      method_option :folder_id, :type => :numeric, :desc => 'Folder ID'
      method_option :since, :desc => 'Last modification date. Show only scans changed since then. Default 7 days.'
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
        # Protect against empty results.
        result['scans'] ||= []
        self.class.table_for(result['scans'], options['columns'], "Scans since #{Time.at(since).to_s}") do |scan|
          options['columns'].map { |column| (column.match('date') && scan[column].is_a?(Integer)) ? Time.at(scan[column]).to_s : scan[column] }
        end
        if result['scans'].length > 0
          columns = result['scans'].first.keys
          say("Available columns:\n" + columns.join(', '))
        end
      end

      desc "scan update-targets SCAN_ID", "Update the targets for a scan."
      method_option :target_file, :desc => 'File containing a list of target fully-qualified hostnames (one per line).'
      method_option :target_list, :type => :array, :desc => 'List of space separated fully-qualified hostnames'
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

      desc "scan launch SCAN_ID", "Launch a scan."
      method_option :target_file, :desc => 'File containing a list of target fully-qualified hostnames (one per line).'
      method_option :target_list, :type => :array, :desc => 'List of space separated fully-qualified hostnames'
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
         say("Scan #{scan_id} launched with UUID #{data['scan_uuid']}")
      end

      desc "scan download SCAN_ID", 'Download the most recent results for a scan identified by a numeric ID'
      method_option :chapters, :type => :array, :default => ['vuln_hosts_summary'], :desc => 'Sections to include in the report. Valid sections: vuln_hosts_summary, vuln_by_host, compliance_exec, remediations, vuln_by_plugin, compliance'
      method_option :format, :default => 'pdf', :desc => 'Available formats: pdf, nessus, html, csv, db'
      method_option :history_id, :aliases => '--hist', :desc => 'History ID if you want to get something other than the most recent scan.'
      self.common_options
      def download(scan_id)
        client = self.class.client(options[:home])
        body = {
          'format' => options[:format],
          'chapters' => options[:chapters],
        }
        filename = client.export_download_scan(scan_id, body, options[:home], options[:history_id])
        say("Scan downloaded to #{filename}")
      end

      desc "scan info SCAN_ID", 'More detailed information for a scan identified by a numeric ID'
      self.common_options
      def info(scan_id)
        client = self.class.client(options[:home])
        details = client.get("/scans/#{scan_id}")
        self.class.table_for(details['info'], ['Name', 'Value'], "Scan info for '#{details['info']['name']}' (#{scan_id})") do |row|
          [row[0], row[0].match(/(timestamp|_start|_end)$/) ? Time.at(row[1]).to_s : row[1].inspect]
        end
      end

      desc "scan history SCAN_ID", 'History information for a scan identified by a numeric ID'
      method_option :columns, :aliases => '-c', :type => :array, :default => %w(history_id status last_modification_date), :desc => 'List of columns to display in a table'
      self.common_options
      def history(scan_id)
        client = self.class.client(options[:home])
        details = client.get("/scans/#{scan_id}")
        self.class.table_for(details['history'], options['columns'], "Scan history for '#{details['info']['name']}' (#{scan_id})") do |scan|
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