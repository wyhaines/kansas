class Object
  def expr_body
    to_s
  end
end

class Array
  def expr_body
    collect { |e| e.expr_body }.join(',')
  end
end

class String
  def expr_body
    sql_escape(self)
  end
end

module Kansas
  class Expression
    include DRbUndumped

    class Context

      attr_reader :tables, :joins, :select, :select_table, :sort_fields, :limits, :distinct

      def initialize(*tables)
#			@select = tables.collect {|t| t.table_name}
        @select = tables[0].table_name
        @select_table = tables[0]
        @tables = []
        @joins = []
        @sort_fields = []
        @limits = []
        @distinct = {}
      end
    end

    def select_sql
      distinct_fields = []
      fields = []
      @context.select_table.fields.each_value do |f|
        if @context.distinct[f]
          distinct_fields.push "distinct(#{@context.select}.#{f})"
        else
          fields.push "#{@context.select}.#{f}"
        end
      end

      fields = distinct_fields.concat(fields)

      selectedTables = @context.tables.compact.flatten.uniq.join(',')
      joinConstraints = @context.joins.compact.flatten.uniq.join(' AND ')
      #selected_rows = @context.select.compact.flatten.uniq.collect {|t| "#{t}.*"}.join(',')

      if joinConstraints != ""
        joinConstraints << " AND "
      end

      #statement = "SELECT #{@context.select}.* FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
      statement = "SELECT #{fields.join(',')} FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
      statement << ' ORDER BY ' << @context.sort_fields.collect { |f| "#{f[0].respond_to?(:expr_body) ? f[0].expr_body : f[0].to_s} #{f[1]}" }.join(',') if @context.sort_fields.length > 0
      statement << ' LIMIT ' << @context.limits.join(',') if @context.limits.length > 0

      statement
    end

    alias :sql :select_sql

    def count_sql
      selectedTables = @context.tables.compact.flatten.uniq.join(',')
      joinConstraints = @context.joins.compact.flatten.uniq.join(' AND ')
      #selected_rows = @context.select.compact.flatten.uniq.collect {|t| "#{t}.*"}.join(',')

      if joinConstraints != ""
        joinConstraints << " AND "
      end

      statement = "SELECT count(*) FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
      statement << ' ORDER BY ' << @context.sort_fields.collect { |f| "#{f[0].respond_to?(:expr_body) ? f[0].expr_body : f[0].to_s} #{f[1]}" }.join(',') if @context.sort_fields.length > 0
      statement << ' LIMIT ' << @context.limits.join(',') if @context.limits.length > 0

      statement
    end

    def delete_sql
      selectedTables = @context.tables.compact.flatten.uniq.join(",")
      joinConstraints = @context.joins.compact.flatten.uniq.join(" AND ")
      if joinConstraints != ""
        joinConstraints << " AND "
      end

      statement = "DELETE FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"

      statement
    end

    def Expression.operator(name, keyword, op=nil)
      opClass = Class.new(BinaryOperator)
      opClass.setKeyword(keyword)
      const_set(name, opClass)

      fn = op ? op : name
      class_eval <<-EOS
define_method(:"#{fn}") {|val| #{name}.new(self, val, @context) }
      EOS
      alias_method name, op if op
    end

    def Expression.binary_function(name, keyword, op = nil, class_to_use = FunctionOperator)
      opClass = Class.new(class_to_use)
      opClass.setKeyword(keyword)
      const_set(name, opClass)

      class_eval <<-EOS
define_method(:"#{name}") {|*val| #{name}.new(self,val,@context) }
      EOS
      alias_method op, name if op
    end

    def Expression.unary_function(name, keyword, op = nil, class_to_use = UnaryFunction)
      opClass = Class.new(UnaryFunction)
      opClass.setKeyword(keyword)
      const_set(name, opClass)

      class_eval <<-EOS
define_method(:"#{name}") {|*val| #{name}.new(val, @context) }
      EOS
      alias_method op, name if op
    end

    def Expression.unary_operator(name, keyword, op=nil)
      opClass = Class.new(UnaryOperator)
      opClass.setKeyword(keyword)
      const_set(name, opClass)

      class_eval <<-EOS
define_method(:"#{name}") { #{name}.new(self, @context) }
      EOS

      alias_method op, name if op
    end

    class Operator < Expression

      def Operator.setKeyword(k)
        @keyword = k
      end

      def Operator.keyword
        @keyword
      end

      def keyword
        self.class.keyword
      end
    end

    class BinaryOperator < Operator
      def initialize(a, b, context)
        @a, @b, @context = a, b, context
      end

      def expr_body
        "(#{@a.expr_body} #{keyword} #{@b.expr_body})"
      end
    end

    class UnaryOperator < Operator
      def initialize(a, context)
        @a, @context = a, context
      end

      def expr_body
        "#{@a.expr_body} #{keyword}"
      end
    end

    class UnaryFunction < Operator
      def initialize(a, context)
        @a, @context = a, context
      end

      def expr_body
        "#{keyword}(#{@a.expr_body})"
      end
    end

    class FunctionOperator < Operator
      def initialize(a, b, context)
        @a, @b, @context = a, b, context
      end

      def expr_body
        "#{@a.expr_body} #{keyword}(#{@b.expr_body})"
      end
    end

    class BetweenFunction < FunctionOperator
      def expr_body
        "#{@a.expr_body} #{keyword} #{@b[0].expr_body} AND #{@b[1].expr_body}"
      end
    end

  end

  class TableExpr < Expression

    def initialize(table, context = nil)
      @table = table
      @context = context ? context : Expression::Context.new(table)
      @context.tables << table.table_name
    end

    def sort_by(*exprs)
      exprs.each do |sort_field|
        if Hash === sort_field
          sort_field.each_pair do |k, v|
            /desc/i.match(v) ? 'DESC' : 'ASC'
            @context.sort_fields.push [k, v]
          end
        else
          @context.sort_fields.push [sort_field, 'ASC']
        end
      end
      TrueExpr.new(@context)
    end

    alias :order_by :sort_by

    def limit(*exprs)
      exprs.each do |e|
        @context.limits.push e
      end
      TrueExpr.new(@context)
    end

    def distinct(*exprs)
      exprs.each do |e|
        @context.distinct[e.field] = true
      end
      TrueExpr.new(@context)
    end

    def field(name, *args, &block)
      if match = /^_(.*)/.match(name.to_s)
        func = match[1]
        FuncExpr.new(@table, func, @context, args)
      elsif field = @table.fields[name.to_s]
        FieldExpr.new(@table, field, @context)
      elsif @table.relations and relation = @table.relations[name.to_s]
        @context.joins << relation.join
        TableExpr.new(relation.foreignTable, @context)
      else
        meth = Expression.method(name.to_s)
        meth.call(args, &block)
      end
    end

    def respond_to?(method)
      if match = /^_(.*)/.match(method.to_s)
        true
      elsif field = @table.fields[method.to_s]
        true
      elsif @table.relations and relation = @table.relations[method.to_s]
        true
      else
        Expression.respond_to?(method.to_s)
      end
    end

    def method_missing(method, *args)
      # _blahblah() indicates that blahblah is a function to be invoked
      # on the database side.  This is a bit of a hack, but I don't have a
      # better solution in my head at the moment.
      if match = /^_(.*)/.match(method.to_s)
        func = match[1]
        FuncExpr.new(@table, func, @context, args)
      elsif field = @table.fields[method.to_s]
        FieldExpr.new(@table, field, @context)
      elsif @table.relations and relation = @table.relations[method.to_s]
        @context.joins << relation.join
        TableExpr.new(relation.foreignTable, @context)
      elsif Expression.respond_to?(method.to_s)
        meth = Expression.method(method.to_s)
        meth.call(args)
      else
        raise BadFieldName, "BadFieldName: '#{method}' is not a valid field name"
      end
    end

    def expr_body
      @table
    end
  end

  class TrueExpr < Expression
    def initialize(context)
      @context = context
    end

    def expr_body
      '1'
    end
  end

  class FieldExpr < Expression

    def initialize(table, field, context)
      @table, @field, @context = table, field, context
    end

    def field
      @field
    end

    def expr_body
      "#{@table.table_name}.#{@field}"
    end

    alias :old_respond_to? :respond_to?

    def respond_to?(method)
      old_respond_to?(method)
    end

    def method_missing(method, *args, &block)
      super(method, *args, &block)
    end
  end

  class FuncExpr < Expression
    def initialize(table, func, context, args)
      @table, @func, @context, @args = table, func, context, args
    end

    def expr_body
      "#{@func}(#{@args.join(',')})"
    end
  end

# These are the recognized relational operators.

  Expression.operator(:AND, "AND", :&)
  Expression.operator(:OR, "OR", :|)
  Expression.operator(:LT, "<", :<)
  Expression.operator(:GT, ">", :>)
  Expression.operator(:LTE, "<=", :<=)
  Expression.operator(:GTE, ">=", :>=)
  Expression.operator(:LIKE, "LIKE", :=~)
  Expression.operator(:EQ, "=", :==)
  Expression.operator(:NEQ, "<=>", :<=>)
  Expression.operator(:NOTEQ, "!=", :noteq)
  Expression.operator(:NOTEQ2, "!=", :'!=')
  Expression.unary_operator(:IS_NULL, "IS NULL", :is_null)
  Expression.unary_operator(:IS_NOT_NULL, "IS NOT NULL", :is_not_null)
  Expression.binary_function(:IN, "IN", :in)
  Expression.binary_function(:BETWEEN, "BETWEEN", :between, Expression::BetweenFunction)
  Expression.binary_function(:NOT_IN, "NOT IN", :not_in)
  Expression.binary_function(:NOT_BETWEEN, "NOT BETWEEN", :not_between, Expression::BetweenFunction)
  Expression.unary_function(:GREATEST, "GREATEST", :greatest)
  Expression.unary_function(:LEAST, "LEAST", :least)
  Expression.unary_function(:MIN, "MIN", :min)
  Expression.unary_function(:MAX, "MAX", :max)

end