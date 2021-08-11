$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'stretchy'
require 'faraday'
require 'awesome_print'
require 'pry'

SPEC_INDEX    = 'stretchy_test'
FIXTURES      = {}

Gem.find_files('**/*.json').each do |path|
  name = File.basename(path, '.json').to_sym
  FIXTURES[name] = JSON.parse(File.read(path))
end

RSpec.configure do |config|
  config.before(:suite) do
    # wait & retry for Docker-based testing
    Stretchy.client = Elasticsearch::Client.new(
      retry_on_failure: 5,
      request_timeout:  5 * 60
    )

    Stretchy.delete_index(SPEC_INDEX)
    Stretchy.create_index(SPEC_INDEX, body: {
      mappings: FIXTURES[:mappings_stub]
    })

    FIXTURES.each do |name, data|
      next if name =~ /stub/
      Stretchy.index_document(
        index:  SPEC_INDEX,
        id:     data['id'],
        body:   data
      )
    end
    Stretchy.client.indices.refresh(index: SPEC_INDEX)
  end
end

RSpec.shared_context 'integration specs', :integration do
  let(:api) { Stretchy.query(index: SPEC_INDEX) }
  let(:found) { FIXTURES[:sakurai] }
  let(:not_found) { FIXTURES[:mizuguchi] }
  let(:extra) { FIXTURES[:suda] }

  subject { api }

  def check_query(a)
    ids = a.ids
    expect(ids).to      include(found['id'])
    expect(ids).not_to  include(not_found['id'])
  end

  def check_filter(a)
    check_query(a)
    scores = api.scores.values
    expect(scores.all?{|s| s == scores.first}).to eq(true)
  end

  def check_boost(a)
    scores = a.scores
    expect(scores[found['id']]).to be > scores[not_found['id']]
  end
end

def fixture(name)
  return FIXTURES[name] if FIXTURES[name]
end
