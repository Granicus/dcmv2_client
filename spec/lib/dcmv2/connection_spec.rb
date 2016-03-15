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

  context "when making a request" do
    let(:connection) { DCMv2::Connection.new(api_key) }

    it "returns a parsed response for HTTPOK", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPOK.new(0,200,""))
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:parsed_response).and_return("OKAY RESPONSE")
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      connection.make_request().should == {status: 200, body: "OKAY RESPONSE"}
    end

    it "returns a parsed response for HTTPCreated", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPCreated.new(0,201,""))
      allow(response).to receive(:code).and_return(201)
      allow(response).to receive(:parsed_response).and_return("OKAY RESPONSE")
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      connection.make_request().should == {status: 201, body: "OKAY RESPONSE"}
    end

    it "returns a parsed response for HTTPAccepted", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPAccepted.new(0,202,""))
      allow(response).to receive(:code).and_return(202)
      allow(response).to receive(:parsed_response).and_return("OKAY RESPONSE")
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      connection.make_request().should == {status: 202, body: "OKAY RESPONSE"}
    end

    it "raises DCMv2 Unauthorized for HTTPUnauthorized", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPUnauthorized.new(0,401,""))
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      expect { connection.make_request() }.to raise_error(DCMv2::Unauthorized)
    end

    it "raises DCMv2 NotFound for HTTPNotFound", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPNotFound.new(0,404,""))
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      expect { connection.make_request() }.to raise_error(DCMv2::NotFound)
    end

    it "raises DCMv2 Suppressed for HTTPConflict", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPConflict.new(0,409,""))
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      expect { connection.make_request() }.to raise_error(DCMv2::Suppressed)
    end

    it "raises DCMv2 InvalidRequest for HTTPClientError 422", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPClientError.new(0,422,""))
      allow(response).to receive(:code).and_return(422)
      allow(response).to receive(:parsed_response).and_return("ERROR: NOT FOUND!")
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      expect { connection.make_request() }.to raise_error(DCMv2::InvalidRequest, "ERROR: NOT FOUND!")
    end

    it "raises DCMv2 ClientError for other HTTPClientError", active:true do
      response = double("response")
      allow(response).to receive(:response).and_return(Net::HTTPClientError.new(0,418,""))
      allow(response).to receive(:code).and_return(418)
      expect(DCMv2::Connection).to receive(:get).and_return(response)
      expect { connection.make_request() }.to raise_error(DCMv2::ClientError)
    end

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
  end
end

