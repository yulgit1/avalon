class BookmarksController < CatalogController
  include Blacklight::Bookmarks
  self.add_action :delete, :delete_action
  self.add_action :playlist
  def delete_action documents
    errors = []
    success_count = 0
    Array(documents.map(&:id)).each do |id|
      media_object = MediaObject.find(id)
      if can? :destroy, media_object
        media_object.destroy
        success_count += 1
      else
        errors += [ "#{media_object.title} (#{params[:id]}) permission denied" ]
      end
    end
    message = "#{success_count} #{'media object'.pluralize(success_count)} successfully deleted."
    message += "These objects were not deleted:</br> #{ errors.join('<br/> ') }" if errors.count > 0
    flash[:notice] = message
  end
end
