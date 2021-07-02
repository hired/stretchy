require 'spec_helper'

module Stretchy
  describe Results do

    let(:request)  { fixture(:request_stub)  }
    let(:response) { fixture(:response_stub) }
    let(:results)  { described_class.new request, response }
    let(:ids)      { response['hits']['hits'].map{|r| r['_id'].to_i } }

    subject { results }

    describe '#limit' do
      it 'matches request[size]' do
        expect(subject.limit).to eq(request['size'])
      end
    end

    describe '#offset' do
      it 'matches request[from]' do
        expect(subject.offset).to eq(request['from'])
      end
    end

    describe '#current_page' do
      it 'matches page' do
        expect(subject.current_page).to eq(1)
      end
    end

    describe '#total' do
      it 'matches response total' do
        expect(subject.total).to eq(response['hits']['total']['value'])
      end
    end

    describe '#total_pages' do
      it 'matches response total and limit' do
        expect(subject.total_pages).to eq(1)
      end
    end

    describe '#results' do
      subject { results.results }

      it 'is an array of hashes' do
        doc = response['hits']['hits'].first['_source']
        ret = subject.find {|r| r['url_slug'] == doc['url_slug']}
        expect(ret).to include(doc)
      end
    end

    describe '#ids' do
      subject { results.ids }

      it 'is equal to document ids' do
        expect(subject).to match_array(ids)
      end
    end

    describe '#scores' do
      subject { results.scores }

      it 'maps the scores for each document' do
        ids.each do |id|
          expect(subject[id]).to be_a Numeric
        end
      end
    end

    describe '#explanations' do
      subject { results.explanations }

      it 'provides hashes of explanations' do
        ids.each do |id|
          expect(subject[id]).to be_a Hash
        end
      end
    end

  end
end
