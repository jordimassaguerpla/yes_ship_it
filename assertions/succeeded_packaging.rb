module YSI
 class SucceededPackaging < Assertion
   needs "obs_project"
   def self.display_name
     "succeeded packaging"
   end

   def check
     if !YSI::ObsHelper.obs_project_results_succeeded?(@engine.obs_project_name)
       return  nil
     end
     "succeeded"
   end

   def assert(executor)
       raise AssertionError.new("Package has not built successfuly upstream. Come back when it does")
   end

 end
end
