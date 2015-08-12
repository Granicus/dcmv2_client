require 'spec_helper'

describe DCMv2::Connection do
  let(:account_id) { 96778814 }
  let(:api_key)    { '42' }

  it "has an API key" do
    connection = DCMv2::Connection.new(api_key)
    connection.api_key.should == '42'
  end

  it "configures the API key at the module level" do
    DCMv2.api_key = api_key
    connection = DCMv2::Connection.new

    connection.api_key.should == '42'
  end

  context "when building a url" do
    let(:connection) { DCMv2::Connection.new(api_key) }

    it "returns only the base url when nil is passed in" do
      connection.url_for(nil).should == DCMv2::Connection.base_uri + "/api/v2"
    end

    it "does not prepend the account id when the passed in url has a leading slash" do
      connection.url_for('/api/v2').should == DCMv2::Connection.base_uri + "/api/v2"
    end

    it "does not prepend the account id when the passed in url has a leading 'http'" do
      connection.url_for('https://stage-api.govdelivery.com/api/v2').should == "https://stage-api.govdelivery.com/api/v2"
    end

    it "does not prepend the account id when the passed in url has a leading 'https'" do
      connection.url_for('https://stage-api.govdelivery.com/api/v2').should == "https://stage-api.govdelivery.com/api/v2"
    end

    it "appends query parameters when specified" do
      connection.url_for('/api/v2', {q: "test"}).should == DCMv2::Connection.base_uri + "/api/v2?q=test"
    end
  end
end

