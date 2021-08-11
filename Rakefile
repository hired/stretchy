require "bundler/gem_tasks"
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
end

$LOAD_PATH.unshift File.expand_path('lib', __FILE__)
require 'stretchy'

namespace :fixtures do
  task :gen do
    require 'json'

    q = Stretchy.query(index: 'stretchy_test')
          .multi_match(query: 'game')
          .where(url_slug: [
            'masahiro-sakurai',
            'tetsuya-mizuguchi',
            'suda-51'
          ])
          .explain
          .page(1, per_page: 20)

      File.open('spec/fixtures/request_stub.json', 'w') do |f|
      f.puts JSON.pretty_generate(q.request)
    end

    File.open('spec/fixtures/response_stub.json', 'w') do |f|
      f.puts JSON.pretty_generate(q.response)
    end
  end
end
