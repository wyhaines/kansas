module Kansas
	class Adaptors
		List = Hash.new { |h, k| h[k] = [] }

		def self.<<(val)
			List[val.priority] << val
		end

		def self.[]=(key, val)
			List[key] << val
		end

		def self.[](key)
			List[key]
		end

		def self.list
			List
		end

		def self.active_adaptor=(val)
			@active_adaptor = val
		end

		def self.active_adaptor
			@active_adaptor
		end

		def self.find(*args)
			List.keys.sort.each do |priority|
				List[priority].each do |rule|
					if rule.trigger?(*args)
						rule.load(*args)
					end
				end
			end
		end

		def self.to_s
			List.collect { |adaptor| adaptor.to_s }.join("\n")
		end
	end
end