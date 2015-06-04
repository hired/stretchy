require 'spec_helper'

describe 'fulltext searching' do

  subject          { Stretchy.query(type: FIXTURE_TYPE) }
  let(:found)      { fixture(:sakurai) }
  let(:not_found)  { fixture(:mizuguchi) }

  it 'finds results in order' do
    res = subject.fulltext('Game Musician').ids
    expect(res.index(found['id'])).to be > res.index(not_found['id'])
  end

  it 'can boost by fulltext' do
    res = subject.boost.fulltext('_all' => 'Game Developer', weight: 1000).ids
    expect(res.index(found['id'])).to be < res.index(not_found['id'])
  end

end