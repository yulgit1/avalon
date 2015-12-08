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
