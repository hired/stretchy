[![](https://ci.solanolabs.com:443/Hired/stretchy/badges/branches/master?badge_token=062c34bcb84d3502662722bf76a8b4ec9fa073d9)](https://ci.solanolabs.com:443/Hired/stretchy/suites/246591)

# Stretchy

Stretchy is a query builder for [Elasticsearch](https://www.elastic.co/products/elasticsearch). It helps you quickly construct the JSON to send to Elastic, which can get [rather complicated](http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html).

Stretchy is modeled after ActiveRecord's interface and architecture - query objects are immutable and chainable, which makes quickly building the right query and caching the results easy. The goals are:

1. **Intuitive** - If you've used ActiveRecord, Mongoid, or other query builders, Stretchy shouldn't be a stretch
2. **Less Typing** - Queries built here should be _way_ fewer characters than building by hand
3. **Easy** - Implementing the right algorithms for your search needs should be simple

Stretchy is *not*:

1. an integration with ActiveModel to help you index your data - too application specific
2. a way to manage Elasticsearch configuration - see [waistband](https://github.com/taskrabbit/waistband)
3. a general-purpose Elasticsearch API client - see the [elasticsearch gem](http://www.rubydoc.info/gems/elasticsearch-api/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stretchy'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install stretchy

## Usage

Stretchy is still in early development, so it does not yet support the full feature set of the [Elasticsearch API](http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html). There may be bugs, though we try for solid spec coverage. We may introduce breaking changes in minor versions, though we try to stick with [semantic versioning](http://semver.org).

It does support fairly basic queries in an ActiveRecord-ish style.

### Documentation

See [the Stretchy docs on rubydocs](http://www.rubydoc.info/gems/stretchy) for fairly detailed documentation on the API. Specifically, you'll probably want the docs for [the API class](http://www.rubydoc.info/gems/stretchy/Stretchy/API), which exposes the public methods for building queries.

### Configuration

```ruby
Stretchy.client = Elasticsearch::Client.new
```

### Base

```ruby
# returns a Stretchy::API object
api = Stretchy.query(index: 'myapp_development')
```

From here, you can chain the methods to build your desired query.

## Chainable Query Methods

From here, you can chain the following query methods:

* [query](#query) - Add arbitrary json fragment to the query section
* [filter](#filter) - Add arbitrary json fragment to the filter section
* [not](#not) - Get documents not matching passed conditions
* [should](#should) - Increase document score for matching documents
* [fulltext](#fulltext) - generic fulltext search with proximity relevance
* [match](#match) - Elasticsearch match query
* [more_like](#more-like) - Get documents similar to a string or other documents
* [where](#where) - Filter based on fields in the document
* [terms](#terms) - Filter without analyzing strings or symbols
* [range](#range) - Filter for a range of values
* [geo_distance](#geo-distance) - Filter on geo_point fields within a specified distance
* [boost](#boost) - Increasing document score based on different factors
* [near](#near) - Boost score based on how close a number / date / geo point is to an origin
* [field](#field) - Boost based on the numeric value of the passed field
* [random](#random) - Add a deterministic random factor to the document score
* [explain](#explain) - Return score explanations along with documents
* [fields](#fields) - Only return the specified fields
* [page](#limit) - Limit, Offset, and Page to define which results to return

### A note on chaining:

The most utility generated from Stretchy is building composable elements for a `function_score` query, and the boolean logic for queries, filters, and boost functions within. Whenever you use one of the API methods having to do with **context**, you change the state in which the filters or queries afterwards will be applied.

```ruby
# filters out documents matching the terms filer
api = api.filter.not(term: {my_field: 'my_val'})

# constructs a bool: query with the regexp query in the should: clause
api = api.should.query(regexp: {my_field: 'aw*ome'})

# constructs a function_score query, with a boost function (weight 5)
# that boosts the score of documents matching the regexp query
# (a filter of type query:)
api = api.boost.query(regexp: {my_field: 'inter*on'}, weight: 5)
```

As soon as you pass parameters to one of the methods, however, the context resets. This allows setting the context by multiple method chains, then adding a query, filter, or boost function with the context applied.

```ruby
api = api.filter(term: {my_field: 'my_val'}).query(match: {_all: 'hello'})
{
  filtered: {
    query: {match: {_all: 'hello'}},
    filter: {term: {my_field: 'my_val'}}
  }
}

api = api.should.query(match: {_all: 'hello'}).query(match: {_all: 'goodbye'})
{
  bool: {
    must:   {match: {_all: 'goodbye'}},
    should: {match: {_all: 'hello'}}
  }
}

api = api.should.not.query(match: {_all: 'hello'})
         .should.query(match: {_all: 'goodbye'})
{
  bool: {
    must: {},
    must_not: {},
    should: {
      bool: {
        must:     {match: {_all: 'goodbye'}},
        must_not: {match: {_all: 'hello'}}
      }
    }
  }
}
```

Furthermore, API objects are immutable. Each chain method produces a new API object, so you never have to worry about mutation or cache busting. This, each example has `api = api.method.calls`, since you will need to store the new query object to get the results you are expecting.

### <a id="query"></a>Query

```ruby
api = api.match.query(
          multi_match: {
            query: 'super smash bros',
            fields: ['developer.games', 'developer.bio']
          }
        )

api = api.match.not.match.query(
          multi_match: {
            query: 'rez',
            fields: ['developer.games', 'developer.bio']
          }
        )
```

Adds arbitrary JSON as a query. If you want to use a query type not currently supported by Stretchy, you can call this method and pass in the requisite json fragment. You can also prefix this with the context methods to put this query in the right place when you send it to Elastic.

### <a id="filter"></a>Filter

```ruby
api = api.filter(
          geo_polygon: {
              'person.location' => {
                  points: [
                      {lat: 40, lon: -70},
                      {lat: 30, lon: -80},
                      {lat: 20, lon: -90}
                  ]
              }
          }
        )
```

Adds arbitrary JSON as a filter. If you want to use a filter type not currently supported by Stretchy, you can call this method and pass in the requisite json fragment. You can also prefix this with context methods.

### <a id="not"></a>Not

```ruby
api = api.where.not(rating: 0)
         .not.match('angry')
```

If called after a `.where` or `.match`, `.not` will act like that method, but will invert the specified queries or filters. If called before some other method such as `.query()`, it will invert the resulting object.

### <a id="should"></a>Should

```ruby
api = api.match.should(name: 'Ada')
         .should.not.query(regexp: {title: 'boring'})
```

If called after a `.where` or `.match`, `.should` will act like that method, but will combine other queries or filters into a `bool:` type, and place the resulting query or filter objects in the `should:` clause. If called before any query or filter method, it will take the results of that method and apply them in a `should:` clause.

Each `should:` clause inside a query boosts the relevance score.

The `should:` clause without a `must:` clause requires at least one of the `should:` statements to match on a document. In a `bool:` filter, this is really all they do.

See Elastic's documentation for [BoolQuery](http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-bool-query.html) and [BoolFilter](http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-bool-filter.html) for more info.

### <a id="match"></a>Match

```ruby
api = api.match('welcome to my web site')
         .match(title: 'welcome to my web site')
```

Performs a match query for the given string. If given a hash, it will use a match query on the specified fields, otherwise it will default to `'_all'`. By default, a match query searches for any of the analyzed terms, and scores them using Lucene's [practical scoring formula](https://www.elastic.co/guide/en/elasticsearch/guide/current/practical-scoring-function.html), which combines TF/IDF, the vector space model, and a few other niceties.

### <a id="fulltext"></a>Fulltext

```ruby
api = api.fulltext('Generic user-input phrase')
```

Performs a query for the given string anywhere in the document. At least one of the terms must match, and the closer a document is to having the exact phrase, the higher its' score. See the Elasticsearch guide's [article on proximity scoring](https://www.elastic.co/guide/en/elasticsearch/guide/current/proximity-relevance.html) for more info on how this works.

### <a id="more-like"></a>More Like

```ruby
api = api.more_like(ids: [1, 2, 3])
         .more_like(docs: other_search.results)
         .more_like(
           like: 'puppies and kittens are great',
           fields: ['about_me']
         )
```

Finds documents similar to a list of input documents. You must pass in one of the `:ids`, `:docs` or `:like_text` parameters, but everything else is optional. This method accepts any of the params available in the [Elasticsearch more_like_this query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-mlt-query.html).

### <a id="where"></a>Where

```ruby
api = api.where(
  name: 'alice',
  email: [
    'alice@company.com',
    'beatrice.christine@other_company.com'
  ],
  commit_count: 27..33,
  is_robot: nil
)
```

Allows passing a hash of matchable options similar to ActiveRecord's `where` method. To be matched, the document must match each of the parameters. If you pass an array of parameters for a field, the document must match at least one of those parameters.

#### Gotcha

If you pass a string or symbol for a field, it will be converted to a [Term Filter](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-terms-filter.html) for the specified field. Since Elastic analyzes terms by default, what is stored in the elasticsearch index may not _exactly_ match the specified terms.

To use a `match:` query as a filter instead of a `terms:` filter, use the context methods:

```ruby
api = api.filter.match(name: 'Alice', email: 'alice@company.com')
```

### <a id="range"></a>Range

```ruby
api = api.range(rating:       {gte: 3, lte: 5})
         .range(released:     {gte: Time.now - 60*60*24*100})
         .range(quantity      {lt: 100})
         .range(awesomeness:  {gt: 89, lte: 100})
```

Only documents with the specified field, and within the specified range match. You can also pass in dates and times as ranges. While you could pass a normal ruby `Range` object to `.where`, this allows you to specify only a minimum or only a maximum.

### <a id="geo-distance"></a>Geo Distance

```ruby
api = api.geo_distance(
  field:    'coords',
  distance: '20mi',
  origin:   [135.7683, 35.0117]
)
```

Filters for documents where the specified `geo_point` field is within the given range of the `origin` point.

#### Gotchas

The field must be mapped as a `geo_point` field. See [Elasticsearch types](http://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-geo-point-type.html) for more info.

The `origin:` point should be specified in one of the following formats:

```ruby
'35,135'            # string: lat,lon - no space
'drm3btev3e86'      # geohash as a string
[135, 35]           # array: [lon, lat] - two elements, longitude first
{lat: 35, lon: 135} # hash with lat: and lon: keys
```

Note that the lat/lon order is reversed for the array format to comply with [GeoJSON](http://geojson.org/). The hash uses the `lon` key, **not** `lng` . For more information about geohashes, [see Elastic's documentation](https://www.elastic.co/guide/en/elasticsearch/guide/current/geohashes.html).

### <a id="boost"></a>Boost

```ruby
api = api.boost.where(category: 3, weight: 100)
         .boost.range(:awesomeness, min: 10, weight: 10)
         .boost.match.not('sucks')
```

Boosts use a [Function Score Query](http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-function-score-query.html) with filters to allow you to affect the score for the document. Each condition will be applied as a filter with an optional weight.


### <a id="near"></a>Near

```ruby
api = api.boost.near(
  field:  :published_at,
  origin: Time.now,
  scale: '5d',
  decay_function: :linear
)

api = api.boost.near(
  field:  :coords,
  origin: [135.7683, 35.0117],
  scale:  '10mi',
  decay:  0.33,
  weight: 1000,
  decay_function: :gauss
)
```

Boosts a document by how close a given field is to a given `:origin` . Accepts dates, times, numbers, and geographical points. Unlike `.where.range` or `.boost.geo`, `.boost.near` is not a binary operation. All documents get a score for that field, which decays the further it is away from the origin point.

The `:scale` param determines how quickly the value falls off. In the example above, if a document's `:coords` field is 10 miles away from the starting point, its score is about 1/3 that of a document at the origin point.

See the [Function Score Query](http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-function-score-query.html) section on Decay Functions for more info.

### <a id="field"></a>Field

```ruby
api = api.boost.field_value(field: :popularity)
         .boost.field_value(field: :timestamp, factor: 0.5, modifier: :sqrt)
         .boost.field_value(field: :votes, weight: 100)
```

Boosts a document by a numeric value contained in the specified fields. You can also specify a `factor` (an amount to multiply the field value by) and a `modifier` (a function for normalizing values).

See the [Boosting By Popularity Guide](https://www.elastic.co/guide/en/elasticsearch/guide/current/boosting-by-popularity.html) and the [Field Value Factor documentation](http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-function-score-query.html#_field_value_factor) for more info.

### <a id="random"></a>Random

```ruby
api = api.boost.random(user.id)
         .boost.random(seed: user.id, weight: 100)
```

Gives each document a randomized boost with a given seed and optional weight. This allows you to show slightly different result sets to different users, but show the same result set to that user every time.

### <a id="fields"></a>Fields

```ruby
api = api.fields(:name, :email, :id)
```

Instead of returning the entire document, only return the specified fields.

### <a id="limit"></a>Limit, Offset, and Page

```ruby
query = query.limit(20).offset(1000)
# or...
query = query.page(50, per_page: 20)
```

Works the same way as ActiveRecord's limit and offset methods - analogous to Elasticsearch's `from` and `size` parameters. The `.page` method allows you to set both at once, and is compatible with the [Kaminari gem](https://github.com/amatsuda/kaminari).

### <a id="explain"></a>Explain

```ruby
query = query.explain.where()
```

Tells Elasticsearch to return an explanation of the score for each document. See [the explain parameter](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-explain.html) for how this is used, and [the explain API](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-explain.html) for what the explanations will look like.

## Result Methods

* [results](#results) - Result documents from this query
* [ids](#ids) - Ids of result documents instead of the full source
* [response](#response) - Raw response data from Elasticsearch
* [total](#total) - Total number of matching documents
* [explanations](#explanations) - Explanations for document scores
* [per_page](#per_page) - Included with `.limit_value` for Kaminari compatibility

### <a id="results"></a>Results

```ruby
query.results
```

Executes the query and provides the parsed json for each hit returned by Elasticsearch, along with `_index`, `_type`, `_id`, and `_score` fields.

### <a id="ids"></a>Ids

```ruby
query.ids
```

Provides only the ids for each hit. If your document ids are numeric (as is the case for many ActiveRecord integrations), they will be converted to integers.

### <a id="response"></a>Response

```ruby
query.response
```

Executes the query, returns the raw JSON response from Elasticsearch and caches it. Use this to get at search API data not in the source documents.

### <a id="total"></a>Total

```ruby
query.total
```

Returns the total number of matches returned by the query - not just the current page. Makes plugging into [Kaminari](https://github.com/amatsuda/kaminari) a snap.

### <a id="explanations"></a>Explanations

```ruby
query.explanations
```

Collect the `'_explanation'` field for each result, so you can easily see how the document scores were computed.

### <a id="per-page"></a>Per Page, Limit Value, and Total Pages

```ruby
results = query.query_results
results.per_page
results.limit_value
results.total_pages
```

Included in the Results object for Kaminari compatibility.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `pry` for an interactive prompt that will allow you to experiment. Run specs with `rspec`

## Contributing

For bugs and feature requests, please [open a new issue](https://github.com/hired/stretchy/issues/new).

Please see [the CONTRIBUTING guide](https://github.com/hired/stretchy/blob/master/CONTRIBUTING.md) for guidelines on contributing to Stretchy.
