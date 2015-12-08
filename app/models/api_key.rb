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

# A class for generating an API token and inserting it into the database_cleaner
# Running ApiKey.create! will result in the creation of a new token
class ApiKey < ActiveRecord::Base
  before_create :generate_access_token

  private

  # Create a unique access token
  # @return [void] The transaction data for generating the key is logged
  def generate_access_token
    exists = true
    while exists
      self.access_token = SecureRandom.base64.tr('+/=', 'VaR')
      exists = self.class.exists?(access_token: access_token)
    end
  end
end
