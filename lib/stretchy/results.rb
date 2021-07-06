require 'json'
module Stretchy
  class Results

    extend  Forwardable
    include Enumerable
    include Utils::Methods
    delegate [:first, :last, :each] => :results

    attr_reader :request, :response

    # implements null object pattern
    def self.fake
      self.new(
        {size: API::DEFAULT_PER_PAGE, fake: true},
        {'hits' => {'total' => {
          "value" => 3,
          "relation" => "eq"
      }, 'hits' => [], 'aggregations' => {}}}
      )
    end

    def initialize(request, response)
      @request  = request
      @response = response
    end

    def fake?
      !!request[:fake]
    end

    def limit
      (request['size'] || request[:size] || API::DEFAULT_PER_PAGE).to_i
    end
    alias :size         :limit
    alias :limit_value  :limit
    alias :per_page     :limit

    def offset
      (request['from'] || request[:from] || 0).to_i
    end
    alias :from         :offset
    alias :offset_value :offset

    def current_page
      Utils.current_page(offset, limit)
    end

    def total
      response['hits']['total']['value']
    end
    alias :total_count  :total
    alias :count        :total
    alias :length       :total
    alias :size         :total

    def total_pages
      (total.to_f / limit_value).ceil
    end

    def results
      @results ||= response['hits']['hits'].map do |r|
        fields        = r.reject {|k, _| k == '_source' || k == 'fields'}
        fields['_id'] = coerce_id(fields['_id']) if fields['_id']
        source        = r['_source'] || {}

        # Elasticsearch always returns array values when specific
        # fields are selected. Undesirable for single values, so
        # coerce to single values when appropriate
        selected      = r['fields']  || {}
        selected      = Hash[selected.map do |k,v|
          v.is_a?(Array) && v.count == 1 ? [k,v.first] : [k,v]
        end]

        source.merge(selected).merge(fields)
      end
    end
    alias :hits :results
    alias :to_a :results

    def ids
      @ids ||= response['hits']['hits'].map {|r| coerce_id r['_id'] }
    end

    def scores
      @scores ||= Hash[results.map {|r| [coerce_id(r['_id']), r['_score']]}]
    end

    def explanations
      @explanations ||= Hash[results.map {|r|
        [coerce_id(r['_id']), r['_explanation']]
      }]
    end

    def aggregations(*args)
      key = args.map(&:to_s).join('.')
      @aggregations ||= {}
      @aggregations[key] ||= begin
        args.reduce(response['aggregations']) do |agg, name|
          agg = agg[name.to_s] unless agg.nil?
        end
      end
    end
  end
end
