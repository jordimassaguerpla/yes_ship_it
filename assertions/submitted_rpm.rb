module YSI
  class SubmittedRpm < Assertion
    parameter :obs_project

    attr_reader :obs_user, :obs_password
    attr_reader :obs_package_files

    def self.display_name
      "submitted RPM"
    end

    def read_obs_credentials(file_name)
      oscrc = IniFile.load(file_name)
      @obs_user = oscrc["https://api.opensuse.org"]["user"]
      @obs_password = oscrc["https://api.opensuse.org"]["pass"]
    end

    def archive_file_name
      engine.release_archive_file_name
    end

    class RpmSpecHelpers
      def initialize(engine)
        @engine = engine
      end

      def get_binding
        binding
      end

      def version
        @engine.version
      end

      def release_archive
        @engine.release_archive_file_name
      end

      def release_directory
        "#{@engine.project_name}-#{@engine.version}"
      end
    end

    def create_spec_file(template)
      erb = ERB.new(File.read(template))
      erb.result(RpmSpecHelpers.new(engine).get_binding)
    end

    def base_url
      "https://#{obs_user}:#{obs_password}@api.opensuse.org/source/#{obs_project}/#{engine.project_name}"
    end

    def check
      if !obs_project
        raise AssertionError.new("OBS project is not set")
      end
      if !engine.release_archive
        raise AssertionError.new("Release archive is not set. Assert release_archive before submitted_rpm")
      end

      read_obs_credentials(File.expand_path("~/.oscrc"))

      @obs_package_files = []

      begin
        xml = RestClient.get(base_url)
      rescue RestClient::Exception => e
        if e.is_a?(RestClient::ResourceNotFound)
          return nil
        elsif e.is_a?(RestClient::Unauthorized)
          raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
        else
          raise AssertionError.new(e.to_s)
        end
      end

      doc = REXML::Document.new(xml)
      doc.elements.each("directory/entry") do |element|
        file_name = element.attributes["name"]
        @obs_package_files.push(file_name)
      end
      if @obs_package_files.include?(archive_file_name)
        return archive_file_name
      end
      nil
    end

    def assert(executor)
      engine.out.puts "..."

      old_files = []
      @obs_package_files.each do |file|
        next if file == "#{engine.project_name}.spec"
        next if file == archive_file_name
        old_files.push(file)
      end

      engine.out.puts "  Uploading release archive '#{archive_file_name}'"
      url = "#{base_url}/#{archive_file_name}"
      file = File.new(engine.release_archive, "rb")
      executor.http_put(url, file, content_type: "application/x-gzip")

      spec_file = engine.project_name + ".spec"
      engine.out.puts "  Uploading spec file '#{spec_file}'"
      url = "#{base_url}/#{spec_file}"
      content = create_spec_file("rpm/#{spec_file}.erb")
      executor.http_put(url, content, content_type: "text/plain")

      old_files.each do |old_file|
        engine.out.puts "  Removing '#{old_file}'"
        url = "#{base_url}/#{old_file}"
        executor.http_delete(url)
      end

      engine.out.print "... "

      "#{obs_project}/#{engine.project_name}"
    end
  end
end
