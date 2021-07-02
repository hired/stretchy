require 'spec_helper'

describe 'Filters', :integration do
  specify 'basic filter' do
    check_filter subject.filter(terms: {id: [found['id'], extra['id']]})
  end

  specify 'multiple filters' do
    check_filter subject.filter(terms: {id: [found['id'], extra['id']]})
                 .filter(term: {url_slug: found['url_slug']})
  end

  specify 'not filter' do
    check_filter subject.not.filter(term: {id: not_found['id']})
  end

  # these are kind of useless except minimum_should_match
  specify 'should filters' do
    check_filter subject.should.filter(terms: {id: [found['id'], extra['id']]})
                 .should.filter(term: {url_slug: found['url_slug']})
  end

  specify 'query filter' do
    check_filter subject.filter.query(multi_match: {query: 'Gamecube'})
  end

  describe 'where filters' do
    let(:salary_range) { (found['salary'] - 5000)..(found['salary'] + 5000) }

    specify 'term string' do
      check_filter subject.where(url_slug: found['url_slug'])
    end

    specify 'term symbol' do
      check_filter subject.where(url_slug: found['url_slug'].to_sym)
    end

    specify 'array terms' do
      check_filter subject.where(url_slug: [found['url_slug'], 'not-a-slug'])
    end

    specify 'range' do
      check_filter subject.where(salary: salary_range)
    end

    specify 'nil' do
      check_filter subject.where(is_mizuguchi: nil)
    end

    describe 'nested hash filters' do
      specify 'dotted hash terms query' do
        check_filter subject.where(games: {id: [1,2]})
      end

      specify 'nested hash terms query' do
        check_filter subject.where(nested: true, games: {
          comments: {user_id: 3, source: "mobile"}
        })
      end
    end

    specify 'together' do
      check_filter subject.where(
        url_slug:     found['url_slug'],
        salary:       salary_range,
        is_mizuguchi: nil
      )
    end
  end

  specify 'range filter' do
    check_filter subject.filter.range(salary: {gte: found['salary']})
  end

  specify 'geo distance filter' do
    check_filter subject.geo_distance(
      distance: '1mi',
      coords: [found['coords']['lon'], found['coords']['lat']]
    )
  end

end
