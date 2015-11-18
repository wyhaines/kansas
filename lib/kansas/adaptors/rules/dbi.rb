KSAdaptors << KSAdaptorRule.new(
	:name => 'DBI Adaptor',
	:description => 'Provides database access via DBI; this is equivalent to the behavior of the legacy Kansas.',
	:file => '',
	:priority => 1000
	) {|args|
	# This code block determines if this adaptor might be able to handle the request.
	}
