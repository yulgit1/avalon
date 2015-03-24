module Avalon::Encoder
  class EncodingEngine
    def self.submit_job file, opts={}
      #Implement this
      #Return job id
      nil
    end
    def self.progress id
      #Implement this
      #Return hash with :status, percent complete, and 'current operation'
      {}
    end
    def self.details id
      #Implement this
      #Return hash with :status, percent complete, 'current operation', error messages, and array of encoding job derivatives
      {}
    end
  end
end
