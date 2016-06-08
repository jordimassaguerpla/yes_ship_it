module YSI
  class SubmittedRpm < Assertion
    needs "obs_project"
    needs "release_archive"
    parameter :spec_file_path, "rpm"
    parameter :project_metadata_path, "obs"

    attr_reader :obs_package_files

    def obs_project_name
      @engine.obs_project_name
    end

    def self.display_name
      "submitted RPM"
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
      YSI::ObsHelper.obs_package_url(obs_project_name, @engine.project_name)
    end

    def check
      @obs_package_files = nil
      xml = YSI::ObsHelper.obs_package_meta(obs_project_name, @engine.project_name)
      return nil if !xml
      @obs_package_files = []
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

    def create_package_metadata(template)
      erb = ERB.new(File.read(template))
      erb.result(@engine.get_binding)
    end

    def assert(executor)
      engine.out.puts "..."

      if !@obs_package_files
        engine.out.puts "Uploading package metadata"
        content = create_package_metadata("#{project_metadata_path}/package.xml.erb")
        url = "#{YSI::ObsHelper.obs_package_url(obs_project_name, engine.project_name)}/_meta"
        executor.http_put(url, content, content_type: "text/plain")
        @obs_package_files = []
      end

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
      content = create_spec_file("#{spec_file_path}/#{spec_file}.erb")
      executor.http_put(url, content, content_type: "text/plain")

      old_files.each do |old_file|
        engine.out.puts "  Removing '#{old_file}'"
        url = "#{base_url}/#{old_file}"
        executor.http_delete(url)
      end

      engine.out.print "... "

      "#{obs_project_name}/#{engine.project_name}"
    end
  end
end
