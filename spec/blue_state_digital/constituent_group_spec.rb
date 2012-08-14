require 'spec_helper'

describe BlueStateDigital::ConstituentGroup do
  describe ".find_or_create" do
    before(:all) do
      @timestamp = Time.now.to_i

      @new_group_xml = <<-xml_string
<?xml version="1.0" encoding="utf-8"?>
<api>
<cons_group>
<name>Environment</name>
<slug>environment</slug>
<description>Environment Group</description>
<group_type>manual</group_type>
<create_dt>#{@timestamp}</create_dt>
</cons_group>
</api>
xml_string
      @new_group_xml.gsub!(/\n/, "")

      @empty_response = <<-xml_string
<?xml version="1.0" encoding="utf-8"?>
<api>
</api>
xml_string
      @empty_response.strip!

      @exists_response = <<-xml_string
<?xml version="1.0" encoding="utf-8"?>
<api>
<cons_group id='12'>
</cons_group>
</api>
xml_string
      @exists_response.strip!
    end

    it "should create a new group" do
      attrs = { name: "Environment", slug: "environment", description: "Environment Group", group_type: "manual", create_dt: @timestamp }


      BlueStateDigital::Connection.should_receive(:perform_request).with('/cons_group/get_constituent_group_by_slug', {slug:attrs[:slug]}, "GET") { @empty_response }
      BlueStateDigital::Connection.should_receive(:perform_request).with('/cons_group/add_constituent_groups', {}, "POST", @new_group_xml) { @exists_response }

      cons_group = BlueStateDigital::ConstituentGroup.find_or_create(attrs)
      cons_group.id.should == '12'
    end


    it "should not create group if it already exists" do
      attrs = { name: "Environment", slug: "environment", description: "Environment Group", group_type: "manual", create_dt: @timestamp }

      BlueStateDigital::Connection.should_receive(:perform_request).with('/cons_group/get_constituent_group_by_slug', {slug:attrs[:slug]}, "GET") { @exists_response }
      BlueStateDigital::Connection.should_not_receive(:perform_request).with('/cons_group/add_constituent_groups', {}, "POST", @new_group_xml)

      cons_group = BlueStateDigital::ConstituentGroup.find_or_create(attrs)
      cons_group.id.should == '12'
    end
  end

  describe ".from_response" do
    before(:each) do
      @response = <<-xml_string
  <?xml version="1.0" encoding="utf-8"?>
  <api>
  <cons_group id='12' modified_dt="1171861200">
      <name>First Quarter Donors</name>
      <slug>q1donors</slug>
      <description>People who donated in Q1 2007</description>
      <is_banned>0</is_banned>
      <create_dt>1168146000</create_dt>
      <group_type>manual</group_type>
      <members>162</members>
      <unique_emails>164</unique_emails>
      <unique_emails_subscribed>109</unique_emails_subscribed>
      <count_dt>1213861583</count_dt>
  </cons_group>
  </api>
  xml_string
    end

    it "should create a group from an xml string" do
      response = BlueStateDigital::ConstituentGroup.send(:from_response, @response)
      response.id.should == "12"
      response.slug.should == 'q1donors'
    end
  end
  
  it "should add constituent ids to group" do
    cons_group_id = "12"
    cons_ids = ["1", "2"]
    post_params = { cons_group_id: cons_group_id, cons_ids: "1,2" }
    
    BlueStateDigital::Connection.should_receive(:perform_request).with('/cons_group/add_cons_ids_to_group', post_params, "POST")
    
    BlueStateDigital::ConstituentGroup.add_cons_ids_to_group(cons_group_id, cons_ids)
  end
end