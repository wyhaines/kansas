class KSAdaptors

	List = Hash.new { |h,k| h[k] = [] }

	def self.<<(val)
		List[ val.priority ] << val
	end

	def self.[]=( key, val )
		List[ key ] << val
	end

	def self.[]( key )
		List[ key ]
	end

	def self.list
		List
	end

	def self.to_s
		List.collect { |adaptor| adaptor.to_s }.join( "\n" )
	end
end
