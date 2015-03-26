begin
  ActiveFedora.fedora.base_path << "/#{Avalon::Configuration.lookup('fedora.namespace')}"
  ActiveFedora.fedora.root_resource_path << "/#{Avalon::Configuration.lookup('fedora.namespace')}"
  ActiveFedora.fedora.init_base_path
rescue Exception => e
  puts e.message
  puts e.backtrace.join("\n")
end
