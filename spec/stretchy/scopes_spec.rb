require 'spec_helper'

module Stretchy
  describe Scopes do

    class MyModel
      include Stretchy::Scopes
      stretchify index: SPEC_INDEX
      stretch :sakurai, -> { match(name: 'sakurai') }
      stretch :with_salary, ->(num) { where(salary: num) }
    end

    let(:found)     { fixture(:sakurai)   }
    let(:not_found) { fixture(:mizuguchi) }

    def query
      MyModel.search
    end

    def check_results
      expect(subject).to include(found['id'])
      expect(subject).not_to include(not_found['id'])
    end

    subject { query }

    describe 'scopes without arguments' do
      subject { query.sakurai.ids }

      it 'can find documents' do
        check_results
      end
    end

    describe 'scopes with arguments' do
      subject { query.with_salary(found['salary']).ids }

      it 'can find documents' do
        check_results
      end
    end

    describe 'chained scopes' do
      subject { query.with_salary(found['salary']).sakurai.ids }

      it 'can find documents' do
        check_results
      end
    end
  end
end
