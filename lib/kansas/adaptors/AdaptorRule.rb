class KSAdaptorRule
	def initialize(args, &block)
		@name = args[:name] # name of adaptor
		@description = args[:description] # short description of what adaptor provides
		@file = args[:file] # adaptor file to require
		@priority = args[:priority] # rules with a lower priority will be checked first
		@klass = args[:klass] # adaptor class
		@block = block # code to determine if this adaptor should be used
	end

	def name; @name; end
	def description; @description; end
	def file; @file; end
	def priority; @priority; end
	def klass; @klass; end
	def check(*args); @block.call(args); end
end
