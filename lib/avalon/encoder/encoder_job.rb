module Avalon::Encoder
  class EncoderJob
    attr_accessible :id, :original_file, :original_opts, :status, :percent_complete, :current_operation, :error, :derivatives #array of EncoderDerivatives

    def initialize(file, opts = {})
      original_file = file
      original_opts = opts
    end

    def submit!
      #implement me
      #set and return id
    end

    def updateProgress!
      #implement me
      #set and return hash
      {status: :pending, percent_complete: 0, current_operation: ''}
    end

    def finished?
      status == :succeeded || status == :failed || status == :cancelled
    end

    def cancelled?
      statue == :cancelled
    end

    def succeeded?
      status == :succeeded
    end

    def failed?
      status == :failed
    end
  end
end
