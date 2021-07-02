require 'spec_helper'

describe 'Aggregations' do
  let(:found) { fixture(:sakurai) }
  let(:not_found) { fixture(:mizuguchi) }
  let(:extra) { fixture(:suda) }

  subject { Stretchy.query(index: SPEC_INDEX) }

  it 'uses a raw json hash' do
    q = subject.aggs(my_agg: {filter: {term: {url_slug: found['url_slug']}}})
    count = q.aggregations(:my_agg)['doc_count']
    expect(count).to eq(1)
  end

end
