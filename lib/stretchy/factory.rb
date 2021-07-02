module Stretchy
  module Factory

    DEFAULT_WEIGHT  = 1.5
    DEFAULT_SLOP    = 50
    BOOST_OPTIONS   = [
      :filter,
      :function,
      :weight
    ]
    FUNCTION_SCORE_OPTIONS = [
      :boost,
      :max_boost,
      :score_mode,
      :boost_mode,
      :min_score
    ]

    module_function

    def default_context
      {}
    end

    def extract_boost_params!(params)
      Utils.extract_options!(params, BOOST_OPTIONS)
    end

    def extract_function_score_options!(params)
      Utils.extract_options!(params, FUNCTION_SCORE_OPTIONS)
    end

    def dotify_params(params, context)
      if context[:nested]
        Utils.nestify(params)
      else
        Utils.dotify(params)
      end
    end

    def raw_node(params, context)
      if context[:boost]
        raw_boost_node(params, context)
      else
        Node.new(params, context)
      end
    end

    def raw_boost_node(params, context)
      boost_params       = extract_boost_params!(params)
      context[:fn_score] = extract_function_score_options!(params)
      context[:boost]    = true
      context[:filter]   = true
      boost_params.merge!(filter: params) unless Utils.is_empty? params
      Node.new(boost_params, context)
    end

    def context_nodes(params, context = default_context)
      if context[:boost]
        params_to_boost(params, context)
      elsif context[:filter] && !context[:query]
        params_to_filters(dotify_params(params, context), context)
      else
        params_to_queries(dotify_params(params, context), context)
      end
    end

    def params_to_boost(params, context = default_context)
      boost_params        = extract_boost_params!(params)
      context[:fn_score]  = extract_function_score_options!(params)
      subcontext          = context.merge(boost: nil)
      nodes               = context_nodes(params, subcontext)
      collector           = AndCollector.new(nodes, subcontext)

      boost_params.merge!(filter: collector.json) if collector.any?
      if boost_params.count == 1 && boost_params.key?(:filter)
        boost_params[:weight] = DEFAULT_WEIGHT
      end

      Node.new(boost_params, context)
    end

    def params_to_queries(params, context = default_context)
      params.map do |field, val|
        case val
        when Array
          Node.new({match: {
            field => {query: val.join(' '), :operator => :or}
          }}, context)
        when Range
          Node.new({range: {
            field => {gte: val.min, lte: val.max}
          }}, context)
        when Hash
          nested(val, field, context)
        else
          Node.new({match: {field => val}}, context)
        end
      end
    end

    def params_to_filters(params, context = default_context)
      params.map do |field, val|
        case val
        when Range
          Node.new({range: {field => {gte: val.min, lte: val.max}}}, context)
        when nil
          nil_ctx = context.merge(must_not: true)
          Node.new({exists: {field: field}}, nil_ctx)
        when Hash
          nested(val, field, context)
        else
          Node.new({terms: {field => Array(val)}}, context)
        end
      end
    end

    def nested(params, path, context = default_context)
      nodes = if context[:filter] && !context[:query]
        params_to_filters(params, context)
      else
        params_to_queries(params, context)
      end
      json  = AndCollector.new(nodes, context).json

      Node.new({nested: {
        path:   path,
        query:  json
      }}, context)
    end

    # https://www.elastic.co/guide/en/elasticsearch/guide/current/proximity-relevance.html
    def fulltext_nodes_from_string(params, context = default_context)
      subcontext = context.merge(query: true)
      nodes = [raw_node({
          multi_match: {
            query: params,
            minimum_should_match: 1
          }
      }, subcontext)]

      subcontext = subcontext.merge(should: true)
      nodes << Factory.raw_node({
        match_phrase: {
          multi_match: {
            query: params,
            slop:  DEFAULT_SLOP
          }
        }
      }, subcontext)

      nodes
    end

    # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-mlt-query.html
    def more_like_node(params = {}, context = default_context)
      Node.new({more_like_this: params}, context)
    end

    # query and filter use the same syntax
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-range-query.html
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-range-filter.html
    def range_node(params = {}, context = default_context)
      Node.new({range: params}, context)
    end

    # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-geo-distance-filter.html
    def geo_distance_node(params = {}, context = default_context)
      Node.new({geo_distance: params}, context)
    end

    # https://www.elastic.co/guide/en/elasticsearch/reference/current/querydslfunctionscorequery.html#functionfieldvaluefactor
    def field_value_function_node(params = {}, context = default_context)
      context[:fn_score] = extract_function_score_options!(params)
      boost_params       = extract_boost_params!(params)
      Node.new(boost_params.merge(field_value_factor: params), context)
    end

    # https://www.elastic.co/guide/en/elasticsearch/reference/current/querydslfunctionscorequery.html#functionrandom
    def random_score_function_node(params, context = default_context)
      json          = {random_score: {seed: params[:seed], field: :id}}
      json[:weight] = params[:weight] if params[:weight]
      Node.new(json, context)
    end

    # https://www.elastic.co/guide/en/elasticsearch/reference/current/querydslfunctionscorequery.html#functiondecay
    def decay_function_node(params = {}, context = default_context)
      boost_params        = extract_boost_params!(params)
      context[:fn_score]  = extract_function_score_options!(params)
      decay_fn            = params.delete(:decay_function)
      field               = params.delete(:field)
      Node.new({decay_fn => { field => params}}.merge(boost_params), context)
    end

  end
end
