#encoding:utf-8
require 'spec_helper'

describe DCMv2::Resource do
  let(:account_id) { 96778814 }
  let(:connection) { DCMv2::Connection.new('42') }

  it "tracks the links available to it" do
    stub_request(:get, connection.url_for(nil)).to_return(api_v2_response)

    resource = DCMv2::Resource.new(connection, nil)

    resource.links.should =~ %w(self reports)
  end

  context "when at the root" do
    let(:resource) { DCMv2::Resource.new(connection, nil) }

    before(:each) do
      stub_request(:get, connection.url_for(nil)).to_return(api_v2_response)
      stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports")).to_return(api_v2_reports_response)
    end

    it "follows links" do
      report_resource = resource.follow('reports')
      report_resource.links.should =~ %w(self engagement_performance_reports network_performance_reports performance_overview subscriber_performance_reports subscription_performance_reports)
    end

    it "won't follow links not available to it" do
      # engagement_performance_reports aren't available from the root resource
      expect { resource.follow('engagement_performance_reports') }.to raise_error
    end

    it "returns itself when following 'self'" do
      self_resource = resource.follow('self')
      self_resource.should == resource
    end
  end

  context "when at the performance overview report" do
    let(:resource) { DCMv2::Resource.new(connection, "/api/v2/accounts/#{account_id}/reports/performance")}

    before(:each) do
      stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance")).to_return(api_v2_performance_report_response)
      stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/subscriptions")).to_return(api_v2_performance_subscription_report_response)
      stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/subscriptions/2014")).to_return(api_v2_performance_subscription_2014_5_report_response)
    end

    it "has embedded data" do
      resource.embedded_data.should_not be_empty
      resource.embedded_data.should == {
        "subscribers"=>{
          "_links"=>{
            "self"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscribers/2014/5"
            },
            "prev"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscribers/2014/4"
            },
            "year"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscribers/2014"
            },
            "find"=>{
              "templated"=>true,
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscribers/{year}/{month}"
            }
          },
          "year"=>2014,
          "month"=>5,
          "net"=>-2012,
          "total"=>2887263,
          "sources"=>{
            "other"=>0,
            "upload"=>4,
            "network"=>1,
            "direct"=>1,
            "deleted"=>2018
          }
        },
        "subscriptions"=>{
          "_links"=>{
            "self"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscriptions/2014/5"
            },
            "prev"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscriptions/2014/4"
            },
            "year"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscriptions/2014"
            },
            "find"=>{
              "templated"=>true,
              "href"=>"/api/v2/accounts/96778814/reports/performance/subscriptions/{year}/{month}"
            }
          },
          "year"=>2014,
          "month"=>5,
          "net"=>-8005,
          "total"=>6531460,
          "sources"=>{
            "other"=>0,
            "upload"=>12027,
            "network"=>1,
            "direct"=>1,
            "deleted"=>20034
          }
        },
        "network"=>{
          "_links"=>{
            "self"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/network/2014/4"
            },
            "prev"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/network/2014/3"
            },
            "year"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/network/2014"
            },
            "find"=>{
              "templated"=>true,
              "href"=>"/api/v2/accounts/96778814/reports/performance/network/{year}/{month}"
            }
          },
          "year"=>2014,
          "month"=>4,
          "sources"=>[
            {
              "name"=>"& City of Pinole-QC",
              "subscribers"=>1
            },
            {
              "name"=>"\"1\" AUDI(5) ®",
              "subscribers"=>1
            }
          ]
        },
        "engagement"=>{
          "_links"=>{
            "self"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/engagement/2014/4"
            },
            "prev"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/engagement/2014/3"
            },
            "year"=>{
              "href"=>"/api/v2/accounts/96778814/reports/performance/engagement/2014"
            },
            "find"=>{
              "templated"=>true,
              "href"=>"/api/v2/accounts/96778814/reports/performance/engagement/{year}/{month}"
            }
          },
          "year"=>2014,
          "month"=>4,
          "unique_recipients"=>22,
          "engaged_recipients"=>20,
          "engagement_rate"=>"0.909090909090909090909090909090909090909"
        }
      }
    end

    it "cannot follow templated links without options" do
      resource = DCMv2::Resource.new(connection, "/api/v2/accounts/#{account_id}/reports/performance/subscriptions")
      expect { resource.follow('find') }.to raise_error
    end

    it "can follow templated links with required attributes" do
      resource = DCMv2::Resource.new(connection, "/api/v2/accounts/#{account_id}/reports/performance/subscriptions")
      subscription_resource = resource.follow('find', { year: 2014 })
      subscription_resource.data['year'].should == 2014
      subscription_resource.data['month'].should == 5
    end

    it "converts embedded data in a Hash into resources" do
      embedded_resources = resource.embedded_resources

      embedded_resources['subscribers'][0].links.should =~ %w(self year prev find)
    end

    it "converts embedded data in an Array into resources" do
      resource = DCMv2::Resource.new(connection, "/api/v2/accounts/#{account_id}/reports/performance/subscriptions")
      resource.embedded_resources.should_not be_empty
      resource.embedded_resources.size.should <= 12
      resource.embedded_resources['monthly_reports'][0].links.should =~ %w(self year prev find)
    end
  end

  def api_v2_response
    example_file_for('api_v2.txt')
  end

  def api_v2_reports_response
    example_file_for('api_v2_reports.txt')
  end

  def api_v2_performance_report_response
    example_file_for('api_v2_reports_performance.txt')
  end

  def api_v2_performance_subscription_report_response
    example_file_for('api_v2_reports_performance_subscriptions.txt')
  end

  def api_v2_performance_subscription_2014_5_report_response
    example_file_for('api_v2_reports_performance_subscriptions_2014_5.txt')
  end

  def example_file_for(filename)
    File.new(File.join(File.expand_path('../../../responses', __FILE__), filename))
  end
end

