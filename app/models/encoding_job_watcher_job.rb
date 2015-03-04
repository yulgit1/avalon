class EncodingJobWatcherJob < Struct.new(:media_object_id, :encoding_job_id)
  def perform
    job_progress = EncodingEngine.progress(encoding_job_id)
    #Update media object with job status
    #reenqueue unless job.finished?
    if job_progress.succeeded?
      job_details = EncodingEngine.details(encoding_job_id)
      job_details.derivatives.each do |d|
        Derivative.create(d)
      end
    else
      #Do something for errors
    end
  end
end
