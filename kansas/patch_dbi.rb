puts "PATCHING"
module DBI

  class Row
    if RUBY_VERSION =~ /^1\.9/ || RUBY_VERSION =~ /^2/
      def __getobj__
        @arr
      end

      def __setobj__(obj)
        @delegate_dc_obj = @arr = obj
      end
    else
      def clone
        Marshal.load(Marshal.dump(self))
      end

      def dup
        row = self.class.allocate
        row.instance_variable_set :@column_types,  @column_types
        row.instance_variable_set :@convert_types, @convert_types
        row.instance_variable_set :@column_map,    @column_map
        row.instance_variable_set :@column_names,  @column_names
        # this is the only one we actually dup...
        row.instance_variable_set :@arr,           arr = @arr.dup
        row.instance_variable_set :@_dc_obj,       arr
        row
      end
    end

  end

  class ColumnInfo
    def initialize(hash=nil)
      @hash = hash.dup rescue nil
       @hash ||= Hash.new

       # coerce all strings to symbols
       @hash.keys.each do |x|
         if x.kind_of? String
           sym = x.to_sym
           if @hash.has_key? sym
             raise ::TypeError, 
               "#{self.class.name} may construct from a hash keyed with strings or symbols, but not both" 
           end
           @hash[sym] = @hash[x]
           @hash.delete(x)
         end
       end

       super(@hash)
     end
  end

end
