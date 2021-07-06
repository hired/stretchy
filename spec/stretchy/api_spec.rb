require 'spec_helper'

module Stretchy
  describe API do
 
    let(:api) { API.new(index: SPEC_INDEX) }
    subject   { api }

    describe 'pagination' do

      describe '#limit' do
        subject { api.limit(10) }

        it 'propagates to request' do
          expect(subject.request[:size]).to eq(10)
        end

        it 'fetches' do
          expect(subject.limit).to eq(10)
        end
      end

      describe '#offset' do
        subject { api.offset(10) }

        it 'propagates to request' do
          expect(subject.request[:from]).to eq(10)
        end

        it 'fetches' do
          expect(subject.offset).to eq(10)
        end

        it 'aliases as limit_value' do
          expect(subject.limit_value).to eq(10)
        end
      end

      describe '#page' do
        it 'fetches 0-19 for page 1' do
          request = subject.page(1, per_page: 20).request
          expect(request[:from]).to eq(0)
          expect(request[:size]).to eq(20)
        end

        it 'fetches 20-49 for page 2' do
          request = subject.page(2, per_page: 20).request
          expect(request[:from]).to eq(20)
          expect(request[:size]).to eq(20)
        end

        it 'fetches' do
          page = subject.page(2, per_page: 20).page
          expect(page).to eq(2)
        end
      end

      describe '#current_page' do
        it 'fetches' do
          page = subject.page(2, per_page: 20).current_page
          expect(page).to eq(2)
        end
      end
    end
  end
end
