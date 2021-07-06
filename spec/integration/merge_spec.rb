require 'spec_helper'

describe 'merging queries' do
  let(:found) { fixture(:sakurai) }
  let(:not_found) { fixture(:mizuguchi) }

  def api
    Stretchy.query(index: SPEC_INDEX)
  end

  def check(api)
    ids = api.ids
    expect(ids).to include(found['id'])
    expect(ids).to_not include(not_found['id'])
  end

  subject { api }

  it 'can merge two filter queries' do
    check subject.query(multi_match: {query: 'video'}).query(
      api.query(multi_match: {query: 'sakurai'})
    )
  end

  it 'merges filters' do
    check subject.filter(
      terms: {url_slug: ['masahiro-sakurai', 'tetsuya-mizuguchi']}
    ).filter(
      api.filter(term: {is_sakurai: true})
    )
  end

  it 'merges a query as a boost' do
    ids = subject.boost(filter: {terms: {id: [1,2,3]}}, weight: 5).boost(
      api.filter(term: {is_sakurai: true}), weight: 10
    ).ids
    expect(ids.index(found['id'])).to be < ids.index(not_found['id'])
  end

end
