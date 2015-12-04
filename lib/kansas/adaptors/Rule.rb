module Kansas
  class Adaptors
    class Rule

      def self.inherited(klass)
        Adaptors << klass
      end

      PRIORITY = 1000 #default

      def priority
        @priority
      end

      def trigger?(*args)
        Trigger.call(*args)
      end

      def load(*args)
        Adaptors.active_adaptor = Loadder.call(*args)
      end

    end
  end
end