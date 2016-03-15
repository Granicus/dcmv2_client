class DCMv2::Connection
  include HTTParty
  base_uri DCMv2.base_uri
  attr_reader :api_key

  def initialize(key = DCMv2.api_key)
    @api_key = key
  end

  def self.base_path
    '/api/v2'
  end

  def make_request(path = nil, params = {}, type = :get)
    payload = type == :get ? {query: params} : {body: params.to_json}
    payload[:headers] = { "X-AUTH-TOKEN" => self.api_key, "Accept" => "application/hal+json", "Content-Type" => "application/json" }
    response = self.class.send(type, url_for(path), payload)

    case response.response
    when Net::HTTPOK, Net::HTTPCreated, Net::HTTPAccepted
      return {status: response.code, body: response.parsed_response}
    when Net::HTTPUnauthorized
      raise DCMv2::Unauthorized, "Unauthorized response. Please double check your API key."
    when Net::HTTPNotFound
      raise DCMv2::NotFound, "Could not find the requested resource."
    when Net::HTTPConflict
      raise DCMv2::Suppressed, "Email Address or Phone Number has been suppressed. Can not subscribe or message."
    when Net::HTTPClientError
      raise DCMv2::InvalidRequest, response.parsed_response if response.code == 422
    end
    raise DCMv2::ClientError, "An error occurred when connecting to the server. #{response.response.class if response.response}"
  end

  def url_for(path)
    return path if path.to_s =~ /^http(s?):\/\//
    File.join(self.class.base_uri, self.path_for(path))
  end

  def path_for(path)
    path_parts = []
    if path
      path_parts << path
    else
      path_parts << self.class.base_path
    end
    return File.join(*path_parts)
  end
end

class DCMv2::InvalidResource < StandardError; end
class DCMv2::NotFound < StandardError; end
class DCMv2::Suppressed < StandardError; end
class DCMv2::Unauthorized < StandardError; end
class DCMv2::InvalidRequest < StandardError; end
class DCMv2::ClientError < StandardError; end

