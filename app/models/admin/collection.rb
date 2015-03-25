# Copyright 2011-2015, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
# 
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed 
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the 
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

require 'hydra/datastream/non_indexed_rights_metadata'
require 'hydra/model_mixins/hybrid_delegator'
require 'role_controls'
require 'avalon/controlled_vocabulary'
require 'avalon/sanitizer'

class Admin::Collection < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  include Hydra::ModelMixins::HybridDelegator
  include ActiveFedora::Associations
#  include VersionableModel

  has_many :media_objects, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.isMemberOfCollection
  contains 'descMetadata', class_name: 'ActiveFedora::SimpleDatastream' do |sds|
    sds.field :name, :string
    sds.field :unit, :string
    sds.field :description, :string
    sds.field :dropbox_directory_name
  end
  contains 'inheritedRights', class_name: 'Hydra::Datastream::InheritableRightsMetadata'
  contains 'defaultRights', class_name: 'Hydra::Datastream::NonIndexedRightsMetadata', autocreate: true

  validates :name, :uniqueness => { :solr_name => 'name_sim'}, presence: true
  validates :unit, presence: true, inclusion: { in: Proc.new{ Admin::Collection.units } }
  validates :managers, length: {minimum: 1, message: 'Collection requires at least one manager'} 

  has_attributes :name, datastream: :descMetadata, multiple: false
  has_attributes :unit, datastream: :descMetadata, multiple: false
  has_attributes :description, datastream: :descMetadata, multiple: false
  has_attributes :dropbox_directory_name, datastream: :descMetadata, multiple: false
  
  delegate :read_groups, :read_groups=, :read_users, :read_users=,
           :visibility, :visibility=, :hidden?, :hidden=, 
           :local_read_groups, :virtual_read_groups, 
           to: :defaultRights, prefix: :default

  around_save :reindex_members, if: Proc.new{ |c| c.name_changed? or c.unit_changed? }
#  has_model_version 'R3'
  before_create :create_dropbox_directory!

  def self.units
    Avalon::ControlledVocabulary.find_by_name(:units) || []
  end

  def managers
    edit_users & ( RoleControls.users("manager") | (RoleControls.users("administrator") || []) )
  end

  def managers= users
    old_managers = managers
    users.each {|u| add_manager u}
    (old_managers - users).each {|u| remove_manager u}
  end

  def add_manager user
    raise ArgumentError, "User #{user} does not belong to the manager group." unless (RoleControls.users("manager") + (RoleControls.users("administrator") || []) ).include?(user)
    self.edit_users += [user]
    self.inherited_edit_users += [user]
  end

  def remove_manager user
    return unless managers.include? user
    #raise "OneManagerLeft" if self.managers.size == 1 # Requires at least 1 manager

    self.edit_users -= [user]
    self.inherited_edit_users -= [user]
  end

  def editors
    edit_users - managers
  end

  def editors= users
    old_editors = editors
    users.each {|u| add_editor u}
    (old_editors - users).each {|u| remove_editor u}
  end

  def add_editor user
    self.edit_users += [user]
    self.inherited_edit_users += [user]
  end

  def remove_editor user
    return unless editors.include? user
    self.edit_users -= [user]
    self.inherited_edit_users -= [user]
  end

  def depositors
    read_users
  end

  def depositors= users
    old_depositors = depositors
    users.each {|u| add_depositor u}
    (old_depositors - users).each {|u| remove_depositor u}
  end

  def add_depositor user
    # Do not add an edit_user to read_users or they will be removed from edit_users
    unless self.edit_users.include? user
      self.read_users += [user]
      self.inherited_edit_users += [user]
    else
      raise "UserIsEditor"
    end
  end

  def remove_depositor user
    return unless depositors.include? user
    self.read_users -= [user]
    self.inherited_edit_users -= [user]
  end

  def inherited_edit_users
    inheritedRights.edit_access.machine.person
  end

  def inherited_edit_users= users
    p = {}
    (inherited_edit_users - users).each {|u| p[u] = 'none'}
    users.each {|u| p[u] = 'edit'}
    inheritedRights.update_permissions('person'=>p)
  end

  def self.reassign_media_objects( media_objects, source_collection, target_collection)
    source_collection.media_objects -= Array(media_objects)
    target_collection.media_objects += Array(media_objects)
    media_objects.each do |m| 
      m.collection = target_collection
      m.save(validate: false)
    end
    
    source_collection.save!
    target_collection.save!
  end

  def reindex_members
    yield
    self.class.reindex_media_objects pid
  end

  class << self
    def reindex_media_objects pid
      collection = self.find pid
      collection.media_objects.each{|mo| mo.update_index}
    end
    handle_asynchronously :reindex_media_objects
  end

  def to_solr(solr_doc=Hash.new, opts = {})
    super.tap do |solr_doc|
      solr_doc[Solrizer.default_field_mapper.solr_name("name", :facetable, type: :string)] = self.name
      solr_doc[Solrizer.default_field_mapper.solr_name("dropbox_directory_name", :facetable, type: :string)] = self.dropbox_directory_name
    end
  end

  def dropbox
    Avalon::Dropbox.new( dropbox_absolute_path, self )
  end

  def dropbox_absolute_path( name = nil )
    File.join(Avalon::Configuration.lookup('dropbox.path'), name || dropbox_directory_name)
  end

  private


    def create_dropbox_directory!
      name = self.dropbox_directory_name
      
      if name.blank?
        name = Avalon::Sanitizer.sanitize(self.name)
        iter = 2
        original_name = name.dup.freeze

        while File.exist? dropbox_absolute_path(name)
          name = "#{original_name}_#{iter}"
          iter += 1
        end
      end

      absolute_path = dropbox_absolute_path(name)
      
      unless File.directory?(absolute_path)
        begin
          Dir.mkdir(absolute_path)
        rescue Exception => e
          Rails.logger.error "Could not create directory (#{absolute_path}): #{e.inspect}"
        end
      end
      self.dropbox_directory_name = name
    end

end
