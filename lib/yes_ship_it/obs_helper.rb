require "nokogiri"

# See obs api docs in https://build.opensuse.org/apidocs

module YSI
  class ObsHelper
    def self.obs_package_url(obs_project_name, package_name)
      read_obs_credentials
      "#{obs_project_url(obs_project_name)}/#{package_name}"
    end

    def self.obs_project_url(obs_project_name)
      read_obs_credentials
      "https://#{@obs_user}:#{@obs_password}@api.opensuse.org/source/#{obs_project_name}"
    end

    def self.read_obs_credentials(file_name =  File.expand_path("~/.oscrc"))
      return unless !@obs_user || !@obs_password
      oscrc = IniFile.load(file_name)
      @obs_user = oscrc["https://api.opensuse.org"]["user"]
      @obs_password = oscrc["https://api.opensuse.org"]["pass"]
    end

    def self.obs_project_meta(obs_project_name)
      begin
        xml = RestClient.get(obs_project_url(obs_project_name))
        rescue RestClient::Exception => e
          if e.is_a?(RestClient::ResourceNotFound)
            return nil
          elsif e.is_a?(RestClient::Unauthorized)
            raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
          else
            raise AssertionError.new(e.to_s)
          end
        end
      xml
    end

    def self.obs_project_results_succeeded?(obs_project_name)
      begin
        read_obs_credentials
        url = "https://#{@obs_user}:#{@obs_password}@api.opensuse.org/build/#{obs_project_name}/_result"
        xml =  RestClient.get(url)
        rescue RestClient::Exception => e
          if e.is_a?(RestClient::ResourceNotFound)
            return nil
          elsif e.is_a?(RestClient::Unauthorized)
            raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
          else
            raise AssertionError.new(e.to_s)
          end
        end
      !Nokogiri::XML(xml).xpath("//status", "package" => "yes_ship_it_test").any? { |x| x["code"] != "succeeded"}
    end

    def self.obs_request?(source_project_name, target_project_name, rev, states = nil)
      # possible states: new/review/accepted/revoked/declined/superseded
      begin
        read_obs_credentials
        url = "https://#{@obs_user}:#{@obs_password}@api.opensuse.org/request?view=collection&project=#{target_project_name}"
        if states != nil
          url += "&states=#{states}"
        end
        xml = RestClient.get(url)
      rescue RestClient::Exception => e
        if e.is_a?(RestClient::ResourceNotFound)
          return nil
        elsif e.is_a?(RestClient::Unauthorized)
          raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
        else
          raise AssertionError.new(e.to_s)
        end
      end
      request_id = nil
      Nokogiri::XML(xml).xpath("//collection/request").each do |x|
        if x.xpath("action/source").any? { |x| x["project"] == source_project_name && x["rev"] == rev }
          request_id = x["id"]
          break
        end
      end
      request_id
    end

    def self.obs_request_state(request_id)
      begin
        read_obs_credentials
        url = "https://#{@obs_user}:#{@obs_password}@api.opensuse.org/request/#{request_id}"
        xml = RestClient.get(url)
      rescue RestClient::Exception => e
        if e.is_a?(RestClient::ResourceNotFound)
          return nil
        elsif e.is_a?(RestClient::Unauthorized)
          raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
        else
          raise AssertionError.new(e.to_s)
        end
      end
      states = Nokogiri::XML(xml).xpath("//request/state")
      if states.length > 1
        raise AssertionError.new("This request #{request_id} has more than one state")
      end
      states.first["name"]
    end

    def self.obs_request(source_project_name, target_project_name, package, rev)
      puts "Creating a submit request from #{source_project_name} #{package} #{target_project_name}"
      xml = ""\
        "<request>"\
          "<action type=\"submit\">"\
            "<source project=\"#{source_project_name}\" package=\"#{package}\"  rev=\"#{rev}\"/>"\
            "<target project=\"#{target_project_name}\" package=\"#{package}\"  />"\
            "<options></options>"\
          "</action>"\
          "<state name=\"new\"/>"\
          "<description>release #{package} by yes_ship_it</description>"\
        "</request>"

      begin
        read_obs_credentials
        url = "https://#{@obs_user}:#{@obs_password}@api.opensuse.org/request?cmd=create"
        response = RestClient.post(url, xml)
        request_id = Nokogiri::XML(response).xpath("//request").first["id"]
      rescue RestClient::Exception => e
        if e.is_a?(RestClient::ResourceNotFound)
          return nil
        elsif e.is_a?(RestClient::Unauthorized)
          raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
        else
          raise AssertionError.new(e.to_s)
        end
      end
    end

    def self.obs_rev(project_name, package)
      begin
        read_obs_credentials
        url = "https://#{@obs_user}:#{@obs_password}@api.opensuse.org/source/#{project_name}/#{package}"
        xml =  RestClient.get(url)
      rescue RestClient::Exception => e
        if e.is_a?(RestClient::ResourceNotFound)
          return nil
        elsif e.is_a?(RestClient::Unauthorized)
          raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
        else
          raise AssertionError.new(e.to_s)
        end
      end
      Nokogiri::XML(xml).xpath("//directory").first["rev"]
    end

    def self.obs_package_meta(project_name, package_name)
      begin
        xml = RestClient.get(obs_package_url(project_name, package_name))
        rescue RestClient::Exception => e
          if e.is_a?(RestClient::ResourceNotFound)
            return nil
          elsif e.is_a?(RestClient::Unauthorized)
            raise AssertionError.new("No credentials set for OBS. Use osc to do this.")
          else
            raise AssertionError.new(e.to_s)
          end
        end
      xml
    end
  end
end
