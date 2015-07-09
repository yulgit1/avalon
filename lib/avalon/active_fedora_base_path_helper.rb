module Avalon
  module ActiveFedoraBasePathHelper
    def activefedora_base_path(pid); activefeodra_base_route(pid, 'path'); end
    def activefedora_base_url(pid); activefeodra_base_route(pid, 'url'); end
    
    private
    def activefeodra_base_route(pid, kind)
      query = "id\:#{RSolr.solr_escape(pid)}"
      solr_doc = ActiveFedora::SolrService.query(query).first
      raise ActiveFedora::ObjectNotFoundError("Unable to find '#{pid}'") if solr_doc.nil?
      klass = ActiveFedora::SolrService.class_from_solr_document(solr_doc)
      path_method = "#{klass.name.underscore}_#{kind}".to_sym
      send(path_method, pid)
    end
  end
end
