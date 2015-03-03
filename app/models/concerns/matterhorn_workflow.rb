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

module MatterhornWorkflow
  extend ActiveSupport::Concern

  included do
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
  end

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

  def start_processing! file=nil
    #Build hash for single file skip transcoding
    if !file.is_a?(Hash) && (self.workflow_name == 'avalon-skip-transcoding' || self.workflow_name == 'avalon-skip-transcoding-audio')
      file = {'quality-high' => File.new(file_location)}
    end

    if file.is_a? Hash
      files = file.dup
      files.each_pair {|quality, f| files[quality] = "file://" + URI.escape(File.realpath(f.to_path))}
      #The hash below has to be symbol keys or else delayed_job chokes
      Delayed::Job.enqueue MatterhornIngestJob.new({
	title: pid,
	flavor: "presenter/source",
	workflow: self.workflow_name,
	url: files
      })
    else
      #The hash below has to be string keys or else rubyhorn complains
      Delayed::Job.enqueue MatterhornIngestJob.new({
	'url' => "file://" + URI.escape(file_location),
	'title' => pid,
	'flavor' => "presenter/source",
	'filename' => File.basename(file_location),
	'workflow' => self.workflow_name
      })
    end
  end

  def update_progress!( params, matterhorn_response )

    response_duration = matterhorn_response.source_tracks(0).duration.try(:first)

    pct = calculate_percent_complete(matterhorn_response)
    self.percent_complete  = pct[:complete].to_i.to_s
    self.percent_succeeded = pct[:succeeded].to_i.to_s
    self.percent_failed    = (pct[:failed].to_i + pct[:stopped].to_i).to_s

    self.status_code = matterhorn_response.state[0]
    self.failures = matterhorn_response.operations.operation.operation_state.select { |state| state == 'FAILED' }.length.to_s
    current_operation = matterhorn_response.find_by_terms(:operations,:operation).select { |n| n['state'] == 'INSTANTIATED' }.first.try(:[],'description')
    current_operation ||= matterhorn_response.find_by_terms(:operations,:operation).select { |n| ['RUNNING','FAILED','SUCCEEDED'].include?n['state'] }.last.try(:[],'description')
    self.operation = current_operation
    self.error = matterhorn_response.errors.last

    # Because there is no attribute_changed? in AF
    # we want to find out if the duration has changed
    # so we can update it along with the media object.
    if response_duration && response_duration !=  self.duration
      self.duration = response_duration
    end

    save
  end

  def update_progress_on_success!( matterhorn_response )
    # First step is to create derivative objects within Fedora for each
    # derived item. For this we need to pick only those which 
    # have a 'streaming' tag attached
    derivative_data = Hash.new { |h,k| h[k] = {} }
    0.upto(matterhorn_response.streaming_tracks.size-1) { |i|
      track = matterhorn_response.streaming_tracks(i)
      key = track.tags.tag.include?('hls') ? 'hls' : 'rtmp'
      derivative_data[track.tags.quality.first.split('-').last][key] = track
    }

    derivative_data.each_pair do |quality, entries|
      Derivative.create_from_master_file(self, quality, entries, { stream_base: matterhorn_response.stream_base.first })
    end

    # Some elements of the original file need to be stored as well even 
    # though they are not being used right now. This includes a checksum 
    # which can be used to validate the file has not changed. 
    self.mediapackage_id = matterhorn_response.mediapackage.id.first

    unless matterhorn_response.source_tracks(0).nil?
      self.file_checksum = matterhorn_response.source_tracks(0).checksum.first
    end

    save

    run_hook :after_processing
  end

  def calculate_percent_complete matterhorn_response
    totals = {
      :transcode => 70,
      :distribution => 20,
      :cleaning => 0,
      :other => 10
    }

    operations = matterhorn_response.find_by_terms(:operations, :operation).collect { |op|
      type = case op['description']
	     when /mp4/ then :transcode
	     when /^Distributing/ then :distribution
	     else :other
	     end
      { :description => op['description'], :state => op['state'], :type => type }
    }

    result = Hash.new { |h,k| h[k] = 0 }
    operations.each { |op|
      op[:pct] = (totals[op[:type]].to_f / operations.select { |o| o[:type] == op[:type] }.count.to_f)
      state = op[:state].downcase.to_sym
      result[state] += op[:pct]
      result[:complete] += op[:pct] if END_STATES.include?(op[:state])
    }
    result[:succeeded] += result.delete(:skipped) unless result[:skipped].nil?
    result.each {|k,v| result[k] = result[k].round }
    result
  end

end
