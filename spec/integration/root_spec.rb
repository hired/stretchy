require 'spec_helper'

describe 'Root actions' do
  let(:found)     { fixture(:sakurai) }
  let(:not_found) { fixture(:mizuguchi) }
  let(:extra)     { fixture(:suda) }

  subject { Stretchy.query(index: SPEC_INDEX, type: FIXTURE_TYPE) }

  it 'limits fields when specified' do
    subject.fields(:url_slug, :name).each do |result|
      expect(result['url_slug']).to_not be_empty
      expect(result['name']).to_not be_empty
      expect(result['company']).to be_nil
    end
  end

  it 'limits size' do
    expect(subject.limit(1).count).to eq(1)
  end

  it 'runs an offset' do
    expect(subject.offset(1).count).to eq(subject.count - 1)
  end

end