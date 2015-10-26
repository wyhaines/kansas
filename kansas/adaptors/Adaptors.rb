class KSAdaptors

	@@list = Hash.new {|h,k| h[k] = []}

	def KSAdaptors.<<(val)
		@@list[val.priority] << val
	end

	def KSAdaptors[]=(key,val)
		@@list[key] << val
	end

	def KSAdaptors[](key)
		@@list[key]
	end

	def KSAdaptors.list
		@@list
	end

	def KSAdaptors.to_s
		@@list.inspect
	end
end
