module YSI
  class ObsProject < Assertion
    parameter :project_name
    parameter :project_metadata_path, "obs"

    def self.display_name
      "obs project"
    end

    def get_binding
      binding
    end

    def check
      if !project_name
        raise AssertionError.new("OBS project is not set")
      end
      @engine.obs_project_name = nil
      xml = YSI::ObsHelper.obs_project_meta(project_name)
      if !xml
        return nil
      end
      @engine.obs_project_name = project_name
    end

    def create_project_metadata(template)
      erb = ERB.new(File.read(template))
      erb.result(get_binding)
    end

    def assert(executor)
      engine.out.puts "  Uploading project metadata"
      content = create_project_metadata("#{project_metadata_path}/project.xml.erb")
      url = "#{YSI::ObsHelper.obs_project_url(project_name)}/_meta"
      executor.http_put(url, content, content_type: "text/plain")
      @engine.obs_project_name = project_name
    end
  end
end
