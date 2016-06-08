module YSI
 class ObsRequestAccepted < Assertion
   needs "obs_project"
   parameter :target_project_name, "openSUSE:Factory"
   def self.display_name
     "obs request accepted"
   end

   def check
     @rev = YSI::ObsHelper.obs_rev(@engine.obs_project_name, @engine.project_name)
     return YSI::ObsHelper.obs_request?(@engine.obs_project_name, target_project_name, @rev, "accepted")
   end

   def assert(executor)
     request_id = YSI::ObsHelper.obs_request?(@engine.obs_project_name, target_project_name, @rev)
     if !request_id
       request_id = YSI::ObsHelper.obs_request(@engine.obs_project_name, target_project_name, @engine.project_name, @rev)
     end
     state = YSI::ObsHelper.obs_request_state(request_id)
     message = "Request #{request_id} in state #{state}."
     case state
     when "new"
       raise AssertionError.new( message + " Please look for a reviewer.")
     when "review"
       raise AssertionError.new( message + " Wait for the reviewer/s to finish. If they don't, ping them and nicely ask them to review.")
     when "declined"
       raise AssertionError.new( message + " Please see the reason and try again after fixing it.")
     when "accepted"
       raise AssertionError.new( message + " That was not expected because the check failed")
     when "revoked"
       raise AssertionError.new( message + " Please see the reason and try again after fixing it.")
     when "superseded"
       raise AssertionError.new( message + " That was not expecte because I was looking for the latest request.")
     when "deleted"
       raise AssertionError.new( message + " Please see reason and try again after fixing it.")
     else
       raise AssertionError.new( message + " Unexpected state.")
     end
   end

 end
end
