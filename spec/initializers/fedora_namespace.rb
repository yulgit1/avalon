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

require 'spec_helper'

describe 'ID Assignment' do
  let(:namespace) { Avalon::Configuration.lookup('fedora.namespace') }
  let(:id)       { "12345" }
  subject(:object) { ActiveFedora::Base.create(id) }
  it "should assign an id in the correct namespace" do
    expect(object.id).to eq(id)
    expect(object.uri).to eq("#{ActiveFedora.fedora.host}/test/#{namespace}/#{id}")
  end
end
