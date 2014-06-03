require 'httparty'
require 'facets/hash'

module DCMv2
  class << self
    attr_accessor :api_key

    # config/initializers/dcmv2.rb (for instance)
    #
    # ```ruby
    # DCMv2.configure do |config|
    #   config.api_key    = 'my_key'
    #   config.base_uri   = 'http://govdelivery.com
    # end
    # ```
    def configure
      yield self
      true
    end

    def base_uri
      @base_uri ||= 'http://govdelivery.com/'
    end

    def base_uri=(uri)
      DCMv2::Connection.base_uri(@base_uri = uri)
    end
  end
end

require 'dcmv2/connection'
require 'dcmv2/resource'
require 'dcmv2/client'

DCMv2.api_key    = ENV['DCMV2_API_KEY']
DCMv2.base_uri   = ENV['DCMV2_BASE_URI']

