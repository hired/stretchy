require 'spec_helper'

describe Stretchy do
  it 'has a version number' do
    puts "Stretchy: #{Stretchy.inspect} #{Stretchy.class}"
    puts "Stretchy: #{Stretchy::VERSION}"
    expect(Stretchy::VERSION).not_to be nil
  end

  # most config methods are called in spec_helper
  # so we've already verified they work

  it 'has a singleton client' do
    expect(Stretchy.client).to be_a(Elasticsearch::Transport::Client)
    expect(Stretchy.client.object_id).to eq(Stretchy.client.object_id)
  end

  it 'passes from and size arguments correctly' do
    expect(Stretchy.client).to receive(:search).with(
      index: Stretchy.index_name,
      type: FIXTURE_TYPE,
      body: {:query=>{:match_all=>{}}},
      explain: true,
      size: 20,
      from: 1
    )

    Stretchy.search(
      type: FIXTURE_TYPE,
      body: {query: Stretchy::Queries::MatchAllQuery.new.to_search},
      explain: true,
      from: 1,
      size: 20
    )
  end

end
