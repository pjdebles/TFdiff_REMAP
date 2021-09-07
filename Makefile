# =========================================================================== #
# Variables

YUM_PROC_SIMPLE           := /usr/share/perl5/vendor_perl/Proc/Simple.pm
CPAN_PROC_SIMPLE          := /usr/local/share/perl5/Proc/Simple.pm
PROC_SIMPLE               := $(YUM_PROC_SIMPLE)
ALGORITHM_DISTANCE_MATRIX := /usr/local/share/perl5/Algorithm/DistanceMatrix.pm
CAD_CALC                  := /usr/local/share/perl5/CAD/Calc.pm
LOCAL_LIB                 := lib
L_MATH_MARTIX             := $(LOCAL_LIB)/Math/Matrix.pm
L_DDM_DDM                 := $(LOCAL_LIB)/DDM/DDM.pm
GIT_SUBMS                 := $(L_MATH_MARTIX) $(L_DDM_DDM)
CONFIG_INIFILES           := /usr/share/perl5/vendor_perl/Config/IniFiles.pm

ifdef CPAN
   PROC_SIMPLE := $(CPAN_PROC_SIMPLE)
endif

# =========================================================================== #
# Targets

.PHONY: ddmTyrant worker

ddmTyrant: \
   $(GIT) \
   scripts/DDM.pm \
   scripts/Math \
   $(ALGORITHM_DISTANCE_MATRIX) \
   $(CAD_CALC) \
   $(PROC_SIMPLE)

worker: $(CONFIG_INIFILES)
	
# =========================================================================== #
# Files

$(L_MATH_MARTIX):
	git submodule update --init

$(L_DDM_DDM):
	git submodule update --init

scripts/DDM.pm: | $(L_DDM_DDM)
	ln -s ../$(LOCAL_LIB)/DDM/DDM.pm $@

scripts/Math: | $(L_MATH_MARTIX)
	ln -s ../$(LOCAL_LIB)/Math $@

$(ALGORITHM_DISTANCE_MATRIX):
	sudo cpan -i Algorithm::DistanceMatrix

$(CAD_CALC):
	sudo cpan -i CAD::Calc

$(YUM_PROC_SIMPLE):
	sudo yum -y install perl-Proc-Simple

$(CPAN_PROC_SIMPLE):
	sudo cpan -i Proc::Simple

$(CONFIG_INIFILES):
	sudo yum install -y perl-Config-IniFiles
