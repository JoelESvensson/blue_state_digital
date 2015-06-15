require 'spec_helper'
require 'blue_state_digital/connection'
require 'timecop'

describe BlueStateDigital::Connection do
  let(:api_host) { 'enoch.bluestatedigital.com' }
  let(:api_id) { 'sfrazer' }
  let(:api_secret) { '7405d35963605dc36702c06314df85db7349613f' }
  let(:connection) { BlueStateDigital::Connection.new({host: api_host, api_id: api_id, api_secret: api_secret})}

  if Faraday::VERSION != "0.8.9"
    describe '#compute_hmac' do
      it "should not escape whitespaces on params" do
        timestamp = Time.parse('2014-01-01 00:00:00 +0000')
        Timecop.freeze(timestamp) do
          api_call = '/somemethod'
          api_ts = timestamp.utc.to_i.to_s
          OpenSSL::HMAC.should_receive(:hexdigest) do |digest, key, data|
            digest.should == 'sha1'
            key.should == api_secret
            data.should =~ /name=string with multiple whitespaces/
          end

          api_mac = connection.compute_hmac("/page/api#{api_call}", api_ts, { api_ver: '2', api_id: api_id, api_ts: api_ts, name: 'string with multiple whitespaces' })
        end
      end
    end
  end

  describe "#perform_request" do
    context 'POST' do
      it "should perform POST request" do
        timestamp = Time.now
        Timecop.freeze(timestamp) do
          api_call = '/somemethod'
          api_ts = timestamp.utc.to_i.to_s
          api_mac = connection.compute_hmac("/page/api#{api_call}", api_ts, { api_ver: '2', api_id: api_id, api_ts: api_ts })

          stub_url = "https://#{api_host}/page/api/somemethod?api_id=#{api_id}&api_mac=#{api_mac}&api_ts=#{api_ts}&api_ver=2"
          stub_request(:post, stub_url).with do |request|
            request.body.should == "a=b"
            request.headers['Accept'].should == 'text/xml'
            request.headers['Content-Type'].should == 'application/x-www-form-urlencoded'
            true
          end.to_return(body: "body")

          response = connection.perform_request(api_call, params = {}, method = "POST", body = "a=b")
          response.should == "body"
        end
      end

      context 'well stubbed' do
        before(:each) do
          faraday_client = double(request: nil, response: nil, adapter: nil, options: {})
          faraday_client.should_receive(:post).and_yield(post_request).and_return(post_request)
          Faraday.stub(:new).and_yield(faraday_client).and_return(faraday_client)
        end 

        let(:post_request) do
          pr = double(headers: headers, body: '', url: nil)
          pr.stub(:body=)
          options = double()
          options.stub(:timeout=)
          pr.stub(:options).and_return(options)
          pr
        end

        let(:headers) { {} } 

        it "should override Content-Type with param" do
          connection = BlueStateDigital::Connection.new({host: api_host, api_id: api_id, api_secret: api_secret})

          connection.perform_request '/somemethod', { content_type: 'application/json' }, 'POST'

          headers.keys.should include('Content-Type')
          headers['Content-Type'].should == 'application/json'
        end

        it "should override Accept with param" do
          connection = BlueStateDigital::Connection.new({host: api_host, api_id: api_id, api_secret: api_secret})

          connection.perform_request '/somemethod', { accept: 'application/json' }, 'POST'

          headers.keys.should include('Accept')
          headers['Accept'].should == 'application/json'
        end
      end
    end

    it "should perform PUT request" do
      timestamp = Time.now
      Timecop.freeze(timestamp) do
        api_call = '/somemethod'
        api_ts = timestamp.utc.to_i.to_s
        api_mac = connection.compute_hmac("/page/api#{api_call}", api_ts, { api_ver: '2', api_id: api_id, api_ts: api_ts })

        stub_url = "https://#{api_host}/page/api/somemethod?api_id=#{api_id}&api_mac=#{api_mac}&api_ts=#{api_ts}&api_ver=2"
        stub_request(:put, stub_url).with do |request|
          request.body.should == "a=b"
          request.headers['Accept'].should == 'text/xml'
          request.headers['Content-Type'].should == 'application/x-www-form-urlencoded'
          true
        end.to_return(body: "body")

        response = connection.perform_request(api_call, params = {}, method = "PUT", body = "a=b")
        response.should == "body"
      end
    end

    it "should perform GET request" do
      timestamp = Time.now
      Timecop.freeze(timestamp) do
        api_call = '/somemethod'
        api_ts = timestamp.utc.to_i.to_s
        api_mac = connection.compute_hmac("/page/api#{api_call}", api_ts, { api_ver: '2', api_id: api_id, api_ts: api_ts })

        stub_url = "https://#{api_host}/page/api/somemethod?api_id=#{api_id}&api_mac=#{api_mac}&api_ts=#{api_ts}&api_ver=2"
        stub_request(:get, stub_url).to_return(body: "body")

        response = connection.perform_request(api_call, params = {})
        response.should == "body"
      end
    end
  end

  describe "perform_graph_request" do
    let(:faraday_client) { double(request: nil, response: nil, adapter: nil) }

    it "should perform Graph API request" do
      post_request = double
      post_request.should_receive(:url).with('/page/graph/rsvp/add', {param1: 'my_param', param2: 'my_other_param'})
      faraday_client.should_receive(:post).and_yield(post_request).and_return(post_request)
      Faraday.stub(:new).and_yield(faraday_client).and_return(faraday_client)
      connection = BlueStateDigital::Connection.new({host: api_host, api_id: api_id, api_secret: api_secret})

      connection.perform_graph_request('/rsvp/add', {param1: 'my_param', param2: 'my_other_param'}, 'POST')
    end
  end

  describe "#get_deferred_results" do
    it "should make a request" do
      connection.should_receive(:perform_request).and_return("foo")
      connection.get_deferred_results("deferred_id").should == "foo"
    end
  end

  describe "#compute_hmac" do
    it "should compute proper hmac hash" do
      params = { api_id: api_id, api_ts: '1272659462', api_ver: '2' }
      connection.compute_hmac('/page/api/circle/list_circles', '1272659462', params).should == 'c4a31bdaabef52d609cbb5b01213fb267af4e808'
    end
  end
end
