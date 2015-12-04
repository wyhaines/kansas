module DBI
  module SQL
    module BasicQuote
      class Coerce
        def as_timestamp(str)
          return nil if str.nil? or str.empty?
          ary = ParseDate.parsedate(str)
          time = nil
          begin
            time = ::Time.local(*(ary[0,6]))
            if m = /^((\+|\-)\d+)(:\d+)?$/.match(ary[6])
              diff = m[1].to_i * 3600  # seconds per hour
              time -= diff
              time.localtime
            end
          rescue Exception
            time = nil
          end
          time ? DBI::Timestamp.new(time) : DBI::Timestamp.new(0)
        end
      end
    end
  end
end
