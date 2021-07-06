require 'spec_helper'

describe 'Highlights' do
  let(:found) { fixture(:sakurai) }
  let(:not_found) { fixture(:mizuguchi) }
  let(:extra) { fixture(:suda) }
  let(:name) { found['name'].split.first }

  subject do
    Stretchy.query(index: SPEC_INDEX)
      .match(name: name)
      .highlight(fields: {name: {}})
  end

  it 'returns results with highlights' do
    expect(subject.results.first['highlight']).to be_a Hash
  end
end
