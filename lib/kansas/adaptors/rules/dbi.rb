module Kansas
  class Adaptors
    module Rules
      class DBI < Rule
        Trigger = Proc.new do |*args|
          args.first =~ /^dbi/i
        end

        Loader = Proc.new do
          require 'kansas/adaptors/dbi'
          Kansas::Adaptors::DBI
        end
      end
    end
  end
end