# Copyright 2011-2014, The Trustees of Indiana University and Northwestern
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

require 'spec_helper'

describe StreamToken do
  let(:target)      { '232A9B17-CCA8-4368-9599-117D2AF1D2EC' }
  let(:session)     { { :session_id => '00112233445566778899aabbccddeeff' } }
  let(:media_token) { StreamToken.media_token(session) }
  
  describe "existing session" do
    it "should create a token" do
      StreamToken.find_or_create_session_token(session, target).should =~ /^[0-9a-f]{32}$/
    end
  end

  describe "new session" do
    it "should create a token" do
      StreamToken.find_or_create_session_token({}, target).should =~ /^[0-9a-f]{32}$/
    end
  end
  
  describe "verification" do
    let(:stream_token) { StreamToken.find_or_create_by(token: media_token, target: target) }
    let(:token) { [target,media_token].join('-') }
    
    it "should verify a valid token" do
      stream_token.renew!
      expect(StreamToken.validate_token(token)).to eq(target)
    end

    it "should fail verification of nil token" do
      expect { StreamToken.validate_token(nil) }.to raise_error(StreamToken::Unauthorized)
    end
    
    it "should fail verification of expired token" do
      stream_token.update_attribute :expires, Time.now - 2.minutes
      expect { StreamToken.validate_token(token) }.to raise_error(StreamToken::Unauthorized)
    end
    
    it "should renew a token that's within configured expiration limites" do
      new_expiration = Time.now + 2.minutes
      stream_token.update_attribute :expires, new_expiration
      expect(StreamToken.validate_token(token)).to eq(target)
      stream_token.reload
      expect(stream_token.expires).to be > new_expiration
    end
    
    it "should not renew a token that isn't within configured expiration limits" do
      new_expiration = Time.now + 1.year
      stream_token.update_attribute :expires, new_expiration
      expect(StreamToken.validate_token(token)).to eq(target)
      stream_token.reload
      expect(stream_token.expires).to eq(new_expiration)
    end
  end
end
