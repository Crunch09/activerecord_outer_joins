require 'active_record'

module ActiveRecord
  module Querying
    delegate :outer_joins, to: :all
  end

  class Relation
    MULTI_VALUE_METHODS << :outer_joins
  end

  module Associations
    class JoinDependency
      def initialize(base, associations, joins, join_type=nil)
        @base_klass    = base
        @table_joins   = joins
        @join_parts    = [JoinBase.new(base)]
        @associations  = {}
        @reflections   = []
        @alias_tracker = AliasTracker.new(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name) # Updates the count for base.table_name to 1
        build(associations, @join_parts.last, join_type)
      end
    end
  end

  module QueryMethods
    def outer_joins(*args)
      check_if_method_has_arguments!("outer_joins", args)
      spawn.outer_joins!(*args.compact.flatten)
    end

    def outer_joins!(*args) # :nodoc:
      self.outer_joins_values += args
      self
    end


    Relation::MULTI_VALUE_METHODS.each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_values                   # def select_values
          @values[:#{name}] || []            #   @values[:select] || []
        end                                  # end
                                             #
        def #{name}_values=(values)          # def select_values=(values)
          raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
          @values[:#{name}] = values         #   @values[:select] = values
        end                                  # end
      CODE
    end

    def build_arel
      arel = Arel::SelectManager.new(table.engine, table)

      build_joins(arel, joins_values.flatten) unless joins_values.empty?

      unless outer_joins_values.empty?
        build_outer_joins(arel, outer_joins_values.flatten)
      end
      collapse_wheres(arel, (where_values - ['']).uniq)

      arel.having(*having_values.uniq.reject(&:blank?)) unless having_values.empty?

      arel.take(connection.sanitize_limit(limit_value)) if limit_value
      arel.skip(offset_value.to_i) if offset_value

      arel.group(*group_values.uniq.reject(&:blank?)) unless group_values.empty?

      build_order(arel)

      build_select(arel, select_values.uniq)

      arel.distinct(distinct_value)
      arel.from(build_from) if from_value
      arel.lock(lock_value) if lock_value

      arel
    end

    def build_outer_joins(manager, outer_joins)
      buckets = outer_joins.group_by do |join|
        case join
        when Hash, Symbol, Array
          :association_join
        when ActiveRecord::Associations::JoinDependency::JoinAssociation
          :stashed_join
        when Arel::Nodes::Join
          :join_node
        else
          raise 'unknown class: %s' % join.class.name
        end
      end

      build_join_query(manager, buckets, Arel::OuterJoin)

    end

    def build_joins(manager, joins)
      buckets = joins.group_by do |join|
        case join
        when String
          :string_join
        when Hash, Symbol, Array
          :association_join
        when ActiveRecord::Associations::JoinDependency::JoinAssociation
          :stashed_join
        when Arel::Nodes::Join
          :join_node
        else
          raise 'unknown class: %s' % join.class.name
        end
      end

      build_join_query(manager, buckets, Arel::InnerJoin)

    end

    def build_join_query(manager, buckets, join_type=nil)
      association_joins         = buckets[:association_join] || []
      stashed_association_joins = buckets[:stashed_join] || []
      join_nodes                = (buckets[:join_node] || []).uniq
      string_joins              = (buckets[:string_join] || []).map(&:strip).uniq

      join_list = join_nodes + custom_join_ast(manager, string_joins)

      join_dependency = ActiveRecord::Associations::JoinDependency.new(
        @klass,
        association_joins,
        join_list,
        join_type
      )


      join_dependency.graft(*stashed_association_joins)

      @implicit_readonly = true unless association_joins.empty? && stashed_association_joins.empty?

      join_dependency.join_associations.each do |association|
        association.join_to(manager)
      end

      manager.join_sources.concat(join_list)
      manager
    end
  end
end
