require 'spec_helper'

describe 'Queries', :integration do
  specify 'basic query' do
    check_query subject.query(match: { name: "sakurai"})
  end

  describe 'match filters' do
    specify 'string query' do
      check_query subject.match('sakurai')
    end

    specify 'hash query' do
      check_query subject.match(name: 'sakurai')
    end

    specify 'array match query' do
      companies = [found['company'], extra['company']]
      check_query subject.match(company: companies)
    end

    describe 'nested hash queries' do
      specify 'dotted hash match query' do
        check_query subject.match(games: {likes: {user: 'stacy'}})
      end

      specify 'nested hash match query' do
        check_query subject.match(nested: true,
          games: {comments: {comment: 'formed'}}
        )
      end
    end
  end

  specify 'basic query' do
    check_query subject.query(term: { url_slug: found['url_slug']})
  end

  specify 'not query' do
    check_query subject.not.query(term: { url_slug: not_found['url_slug']})
  end

  specify 'should query' do
    q = subject.should.query(match: { name: found['name']})
               .should.query(match: { 'games.platforms' => 'GameCube' })
    sakurai = q.results.find {|r| r['id'] == found['id'] }
    suda    = q.results.find {|r| r['id'] == extra['id'] }

    # .should defaults to "must match at least one filter / query"
    expect(q.ids).to include(found['id'])
    expect(q.ids).to include(extra['id'])
    expect(q.ids).to_not include(not_found['id'])

    # but .should affects the document score: more matchs == higher score
    expect(sakurai['_score']).to be > suda['_score']
  end

  specify 'range query' do
    check_query subject.query.range(salary: {gte: found['salary']})
  end

  specify 'more_like' do
    check_query subject.more_like(
      fields:           ['name'],
      like:             found['name'],
      min_doc_freq:     1,
      min_term_freq:    1
    )
  end

  specify 'fulltext query' do
    check_query subject.fulltext(found['name'])
  end

  describe 'nested queries' do

  end

end
