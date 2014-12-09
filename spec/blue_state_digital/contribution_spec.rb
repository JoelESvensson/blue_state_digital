require 'spec_helper'

describe BlueStateDigital::Contribution do
  let(:attributes) { 
    {
      external_id:      'GUID_1234',
      firstname:        'carlos',
      lastname:         'the jackal',
      transaction_amt:  1.0,
      transaction_dt:   '2012-12-31 23:59:59',
      cc_type_cd:       'vs'
    } 
  }

  it { should have_fields(
    :external_id,
    :prefix,:firstname,:middlename,:lastname,:suffix,
    :transaction_dt,:transaction_amt,:cc_type_cd,:gateway_transaction_id,
    :contribution_page_id,:stg_contribution_recurring_id,:contribution_page_slug,
    :outreach_page_id,:source,:opt_compliance,
    :addr1,:addr2,:city,:state_cd,:zip,:country,
    :phone,:email,
    :employer,:occupation,
    :custom_fields
    ) }

  describe 'as_json' do
    let(:connection) { double }

    it 'should include contribution_page_id and contribution_page_slug if they are set' do
      contribution = BlueStateDigital::Contribution.new(attributes.merge({ connection: connection, contribution_page_slug: 'donate-here-12', contribution_page_id: 4 }))
      expect(contribution.as_json).to include('contribution_page_id')
      expect(contribution.as_json).to include('contribution_page_slug')
    end

    it 'should not include contribution_page_id and contribution_page_slug if they are not set' do
      contribution = BlueStateDigital::Contribution.new(attributes.merge({ connection: connection }))
      expect(contribution.as_json).not_to include('contribution_page_id')
      expect(contribution.as_json).not_to include('contribution_page_slug')
    end
  end

  describe 'save' do
    let(:connection) { double }
    let(:contribution) { BlueStateDigital::Contribution.new(attributes.merge({ connection: connection })) }

    before :each do
      connection
        .should_receive(:perform_request)
        .with(
          '/contribution/add_external_contribution', 
          {accept: 'application/json'}, 
          'POST',
          [contribution].to_json
        )
        .and_return(response)
    end

    context 'successful' do
      let(:response) {
        { 
          'summary'=> { 
            'sucesses'=>   1, 
            'failures'=>     0, 
            'missing_ids'=>  0 
          }, 
          'errors'=> {
          } 
        }.to_json
      }

      it "should perform API request" do
        saved_contribution = contribution.save
        saved_contribution.should_not be_nil
      end
    end

    context 'failure' do
      context 'bad request' do
        let(:response) { 'Method add_external_contribution expects a JSON array.' }
        it "should raise error" do
          expect { contribution.save }.to raise_error(
            BlueStateDigital::Contribution::ContributionSaveFailureException,
            /Method add_external_contribution expects a JSON array/m
          )
        end
      end   
      context 'missing ID' do
        let(:response) {
          { 
            'summary'=> { 
              'sucesses'=>  0, 
              'failures'=>    0, 
              'missing_ids'=>  1
            }, 
            'errors'=>{
            } 
          }.to_json
        }
        it "should raise error" do
          expect { contribution.save }.to raise_error(
            BlueStateDigital::Contribution::ContributionExternalIdMissingException
          )
        end
      end
      context 'validation errors' do
        let(:response) {
          { 
            'summary'=> { 
              'sucesses'=>  0, 
              'failures'=>    1, 
              'missing_ids'=> 0
            }, 
            'errors'=>{ 
              'UNIQUE_ID_1234567890'=>
                [
                  'Parameter source is expected to be a list of strings', 
                  'Parameter email does not appear to be a valid email address.'
                ] 
              }
          }.to_json
        }
        it "should raise error" do
          expect { contribution.save }.to raise_error(
            BlueStateDigital::Contribution::ContributionSaveValidationException,
            /Error for Contribution.ID. UNIQUE_ID_1234567890.. Parameter source is expected to be a list of strings, Parameter email does not appear to be a valid email address/m
            )
        end
      end
    end
  end
end
