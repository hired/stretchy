require 'spec_helper'

describe 'Boosts', :integration do
  specify 'filter' do
    check_boost subject.boost.filter(term: {url_slug: found['url_slug']}, weight: 10)
  end

  specify 'query' do
    check_boost subject.boost.query(multi_match: {query: found['name']}, weight: 10)
  end

  specify 'where' do
    check_boost subject.boost.where(url_slug: found['url_slug'])
  end

  specify 'where with weight' do
    check_boost subject.boost.where(url_slug: found['url_slug'], weight: 100)
  end

  specify 'match with weight' do
    check_boost subject.boost.match(name: found['name'], weight: 100)
  end

  specify 'nested where with weight' do
    check_boost subject.boost.where(nested: true, games: {
      comments: {user_id: 3, source: "mobile"}
    })
  end

  specify 'match' do
    check_boost subject.boost.match(name: found['name'])
  end

  describe 'field value' do
    specify 'with only field' do
      check_boost subject.boost.field_value(field: :salary)
    end

    specify 'with field value options' do
      check_boost subject.boost.field_value(
        field:    :salary,
        factor:   1.2,
        modifier: :square
      )
    end

    specify 'with weight' do
      check_boost subject.boost.field_value(
        field:  :salary,
        factor: 1.2,
        weight: 100
      )
    end
  end

  describe 'random value' do
    let(:seed) { 22 }

    # fortunately, 'random' has a seed
    # unfortunately, when elasticsearch version changes, we may have
    # to pick a new seed here

    specify 'by seed' do
      check_boost subject.boost.random(seed)
    end

    specify 'with weight' do
      check_boost subject.boost.random(seed: seed, weight: 100)
    end
  end

  specify 'distance from value' do
    check_boost subject.boost.near(
      decay_function: :gauss,
      field: :coords,
      origin: found['coords'],
      scale: '2mi',
      weight: 3
    )
  end

  specify 'not filter' do
    check_boost subject.boost.where.not(url_slug: not_found['url_slug'])
  end

  specify 'not matching' do
    check_boost subject.boost.match.not(name: not_found['name'])
  end

  describe 'function_score options' do
    specify 'from boost' do
      q = subject.boost(score_mode: :min)
        .boost.match(bio: 'game', weight: 2)
        .boost.match(bio: 'video', weight: 1000)
      expect(q.scores.all?{|k,s| s < 1000}).to eq(true)
    end

    specify 'within boost' do
      q = subject.boost.match(bio: 'game', weight: 2, score_mode: :min)
        .boost.match(bio: 'video', weight: 1000)
      expect(q.scores.all?{|k,s| s < 1000}).to eq(true)
    end

    specify 'without boost functions' do
      q = subject.boost(score_mode: :min)
        .boost.match(_all: 'game', weight: 2)
      expect(q.request[:body][:query][:function_score][:functions].count).to eq(1)
    end

    specify 'with only options, no functions' do
      q = subject.boost(score_mode: :min)
      expect(q.request[:body][:query][:function_score]).to be_nil
    end
  end

end
