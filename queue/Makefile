# ============================================================================ #
# Vars

BDClient := /usr/share/perl5/vendor_perl/Beanstalk/Client.pm
BDbin    := /usr/bin/beanstalkd
JSON     := /usr/lib64/perl5/vendor_perl/JSON/XS.pm

# ============================================================================ #
# Targets

.PHONY: dependencies

dependencies: $(BDClient) $(BDbin) $(JSON)

# ============================================================================ #
# Files

$(BDClient):
	sudo yum install perl-Beanstalk-Client

$(BDbin):
	sudo yum install beanstalkd

$(JSON):
	sudo yum install perl-JSON
