Pod::Spec.new do |s|  
  s.name             = "ALO7ProgressiveMigrationManager"  
  s.version          = "1.0.2"  
  s.summary          = "Supports progressive migration for iOS Core Data with lightweight and heavyweight migration step mixed."  
  s.homepage         = "https://github.com/alo7/ALO7ProgressiveMigrationManager"  
  s.license          = 'BSD'  
  s.author           = { "fogisland" => "zhukaihua1225@gmail.com" }  
  s.source           = { :git => "https://github.com/alo7/ALO7ProgressiveMigrationManager.git", :tag => s.version.to_s }   
  s.platform     = :ios, '7.0'    
  s.requires_arc = true  
  s.source_files = 'ALO7ProgressiveMigrationManager/*'  
  s.frameworks = 'Foundation', 'CoreData' 
end  
