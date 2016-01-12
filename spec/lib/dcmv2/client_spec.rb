require 'spec_helper'

describe DCMv2::Client do
  let(:account_id) { 96778814 }
  let(:connection) { DCMv2::Connection.new('42') }

  context "when connecting to the API" do
    let(:client) { DCMv2::Client.new(connection) }

    context "when unauthorized" do
      it "doesn't make a request when an api_key is not provided" do
        connection = DCMv2::Connection.new(nil)
        connection.api_key.should be_nil
        client = DCMv2::Client.new(connection)

        expect { client.available_resources }.to raise_error
      end

      it "raises an exception when the server returns a 401" do
        stub_request(:get, connection.url_for(nil)).to_return(unauthorized_response)
        client = DCMv2::Client.new(connection)
        expect { client.available_resources }.to raise_error(DCMv2::Unauthorized)
      end
    end

    context "when authorized" do
      before(:each) do
        stub_request(:get, connection.url_for(nil)).to_return(api_v2_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports")).to_return(api_v2_reports_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance")).to_return(api_v2_reports_performance_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/subscribers")).to_return(api_v2_reports_performance_subscribers_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/subscriptions")).to_return(api_v2_reports_performance_subscriptions_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/engagement")).to_return(api_v2_reports_performance_engagement_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/network")).to_return(api_v2_reports_performance_network_response)
        stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/subscriptions/2014/4")).to_return(api_v2_reports_performance_subscriptions_2014_4_response)
      end

      context "when navigating" do
        it "lists links available from the root" do
          client.available_resources.should =~ %w(self reports)
        end

        it "can get a resource without changing the client's state" do
          expect {
            client.go_to('reports')
          }.to_not change(client, :available_resources)
        end

        it "gets linked resources" do
          expect {
            client.go_to!('reports')
          }.to change(client, :available_resources).from(match_array(%w(self reports))).to(match_array(%w(self engagement_performance_reports network_performance_reports performance_overview subscriber_performance_reports subscription_performance_reports)))
        end

        it "gets results from the performance_overview report" do
          client.go_to!('reports').go_to!('performance_overview')

          client.embedded_data['subscribers'].should_not be_nil
          client.embedded_data['subscriptions'].should_not be_nil
          client.embedded_data['engagement'].should_not be_nil
          client.embedded_data['network'].should_not be_nil
        end

        it "can only navigate to the list of available reports" do
          expect {
            expect { client.go_to!('not_real') }.to raise_error DCMv2::InvalidResource
          }.to_not change { client.current_resource.path }
        end

        context "when going back" do
          it "will not go back when there is no history" do
            expect {
              client.back!
            }.to_not change(client, :current_resource)
          end

          it "can go back a link" do
            expect {
              client.go_to!('reports')
              client.back!
            }.to_not change(client, :available_resources)
          end
        end

        context "when navigating up" do
          it "stays on the current resource when at the base path" do
            expect {
              client.up!
            }.to_not change(client, :current_path)
          end

          it "goes to the parent resource" do
            client.go_to!('reports').go_to!('performance_overview')
            expect {
              client.up!
            }.to change(client, :current_path).from(connection.path_for("/api/v2/accounts/#{account_id}/reports/performance")).to(connection.path_for("/api/v2/accounts/#{account_id}/reports"))
          end

          it "should skip over the accounts resource" do
            client.go_to!('reports').up!
            expect {
              client.up!
            }.to change(client, :current_path).from(connection.path_for("/api/v2/accounts/#{account_id}")).to(connection.path_for(nil))
          end
        end

        context "when navigating embedded resources" do
          before(:each) do
            client.go_to!('reports').go_to!('performance_overview')
          end

          it "has embedded_resources" do
            client.embedded_resources.size.should == 4
            subscriptions = client.embedded_resources['subscriptions'][0]
            subscriptions.links.should match_array(%w(self prev find year))
          end

          it "knows what embedded resources can be followed" do
            client.available_embedded_resources.should =~ [
              'subscribers/0/prev', 'subscribers/0/self', 'subscribers/0/find', 'subscribers/0/year',
              'subscriptions/0/prev', 'subscriptions/0/self', 'subscriptions/0/find', 'subscriptions/0/year',
              'network/0/prev', 'network/0/self', 'network/0/find', 'network/0/year',
              'engagement/0/prev', 'engagement/0/self', 'engagement/0/find', 'engagement/0/year'
            ]
          end

          it "follows links in embedded resources" do
            expect {
              client.go_to_embedded!('subscriptions/0/prev')
            }.to change(client, :current_path).to("/api/v2/accounts/#{account_id}/reports/performance/subscriptions/2014/4")
          end

          it "raises an error when a path is unrecognized" do
            expect {
              expect { client.go_to_embedded!('subscriptions/0/jabberwocky') }.to raise_error(DCMv2::InvalidResource)
            }.to_not change(client, :current_path)
          end

          it "raises an error when an embedded path has no slashes" do
            expect {
              expect { client.go_to_embedded!('subscriptions') }.to raise_error(DCMv2::InvalidResource)
            }.to_not change(client, :current_path)
          end
        end

        context "when jumping to resources" do
          it "jumps to a specified resource name" do
            expect {
              client.jump_to!("/api/v2/accounts/#{account_id}/reports/performance/subscriptions")
            }.to change(client, :current_path).from("/api/v2").to("/api/v2/accounts/#{account_id}/reports/performance/subscriptions")
          end

          it "raises an error when the url is not recognized" do
            stub_request(:get, connection.url_for("/api/v2/accounts/#{account_id}/reports/performance/jabberwocky")).to_return(missing_response)

            client.jump_to!('reports/performance/jabberwocky')
            expect { client.data }.to raise_error
          end
        end

        context "when on the reports index" do
          before(:each) do
            client.go_to!('reports')
          end

          it "can reach a list of reports" do
            client.available_resources.should match_array(%w(self engagement_performance_reports network_performance_reports performance_overview subscriber_performance_reports subscription_performance_reports))
          end

          it "gets results from the subscribers report" do
            client.go_to!('subscriber_performance_reports')

            client.data['end_year'].should == 2014
            client.data['end_month'].should == 5
          end

          it "gets results from the subscriptions report" do
            client.go_to!('subscription_performance_reports')

            client.data['end_year'].should == 2014
            client.data['end_month'].should == 5
          end

          it "gets results from the engagement report" do
            client.go_to!('engagement_performance_reports')

            client.data['end_year'].should == 2014
            client.data['end_month'].should == 4
          end

          it "gets results from the network report" do
            client.go_to!('network_performance_reports')

            client.data['end_year'].should == 2014
            client.data['end_month'].should == 4
          end
        end
      end

      context "signup" do
        before(:each) do
          stub_request(:post, connection.url_for("/api/v2/accounts/#{account_id}/signup")).to_return(suppressed_response)
        end

        it "throws a DCMv2::Suppressed error when attempting to signup a suppressed address" do
          payload = {
            email: "dont.email@sink.govdelivery.com",
            subscribe: {topic_ids: [98463792]},
            reason: "integration_hub",
            source: "salesforce"
          }
          expect{
            client.jump_to!("/api/v2/accounts/#{account_id}/signup", payload, :post).data
          }.to raise_error(DCMv2::Suppressed)
        end
      end
    end
  end

  def unauthorized_response
    example_file_for('unauthorized.txt')
  end

  def missing_response
    example_file_for('missing.txt')
  end

  def suppressed_response
    example_file_for('suppressed.txt')
  end

  def api_v2_response
    example_file_for('api_v2.txt')
  end

  def api_v2_reports_response
    example_file_for('api_v2_reports.txt')
  end

  def api_v2_reports_performance_response
    example_file_for('api_v2_reports_performance.txt')
  end

  def api_v2_reports_performance_subscriptions_response
    example_file_for('api_v2_reports_performance_subscriptions.txt')
  end

  def api_v2_reports_performance_subscriptions_2014_4_response
    example_file_for('api_v2_reports_performance_subscriptions_2014_4.txt')
  end

  def api_v2_reports_performance_subscribers_response
    example_file_for('api_v2_reports_performance_subscribers.txt')
  end

  def api_v2_reports_performance_engagement_response
    example_file_for('api_v2_reports_performance_engagement.txt')
  end

  def api_v2_reports_performance_network_response
    example_file_for('api_v2_reports_performance_network.txt')
  end

  def example_file_for(filename)
    File.new(File.join(File.expand_path('../../../responses', __FILE__), filename))
  end
end

