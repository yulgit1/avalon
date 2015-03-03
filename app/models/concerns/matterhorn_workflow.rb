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

module Avalon
  module AccessControls
    module MatterhornWorkflow
      extend ActiveSupport::Concern

      WORKFLOWS = ['fullaudio', 'avalon', 'avalon-skip-transcoding', 'avalon-skip-transcoding-audio']

      has_metadata name: 'mhMetadata', :type => ActiveFedora::SimpleDatastream do |d|
	d.field :workflow_id, :string
	d.field :workflow_name, :string
	d.field :mediapackage_id, :string
	d.field :percent_complete, :string
	d.field :percent_succeeded, :string
	d.field :percent_failed, :string
	d.field :status_code, :string
	d.field :operation, :string
	d.field :error, :string
	d.field :failures, :string
      end

      has_attributes :workflow_id, :workflow_name, :mediapackage_id, :percent_complete, :percent_succeeded, :percent_failed, :status_code, :operation, :error, :failures, datastream: :mhMetadata, multiple: false

      validates :workflow_name, presence: true, inclusion: { in: Proc.new{ WORKFLOWS } }

      END_STATES = ['STOPPED', 'SUCCEEDED', 'FAILED', 'SKIPPED']

      def set_workflow( workflow  = nil )
	if workflow == 'skip_transcoding'
	  workflow = case self.file_format
		     when 'Moving image'
		      'avalon-skip-transcoding'
		     when 'Sound'
		      'avalon-skip-transcoding-audio'
		     else
		      nil
		     end
	elsif self.file_format == 'Sound'
	  workflow = 'fullaudio'
	elsif self.file_format == 'Moving image'
	  workflow = 'avalon'
	else
	  logger.warn "Could not find workflow for: #{self}"
	end
	self.workflow_name = workflow
      end

    def stop_processing!
      begin
        Rubyhorn.client.stop(workflow_id)
      rescue Exception => e
        logger.warn "Error stopping workflow: #{e.message}"
      end
    end

    end
  end
end
