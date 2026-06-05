FC = gfortran
FFLAGS ?= -g
BUILD_DIR ?= build
VERIFY_BASELINE ?= /Users/jdsimon/mermaid/cfneic
VERIFY_INPUT ?= $(VERIFY_BASELINE)/inputs
VERIFY_OUT ?=
VERIFY_IDENT ?= run1

.PHONY: all verify-run1 clean

all: $(BUILD_DIR)/cfneic $(BUILD_DIR)/rdGPS

$(BUILD_DIR):
	mkdir -p $@

# Source order mirrors the legacy command:
# gfortran -g -o $root/cfneic mod_ttak135.f90 timedel.f90 cfneic.f90
$(BUILD_DIR)/cfneic: mod_ttak135.f90 timedel.f90 cfneic.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -o $@ mod_ttak135.f90 timedel.f90 cfneic.f90

# Source order mirrors the legacy command:
# gfortran -g -o $root/rdGPS rdGPS.f90 timedel.f90
$(BUILD_DIR)/rdGPS: rdGPS.f90 timedel.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -o $@ rdGPS.f90 timedel.f90

install: $(ROOT)/cfneic $(ROOT)/rdGPS

verify-run1: all
	BASELINE_ROOT="$(VERIFY_BASELINE)" INPUT_ROOT="$(VERIFY_INPUT)" VERIFY_OUT="$(VERIFY_OUT)" IDENT="$(VERIFY_IDENT)" ./verify_run1

clean:
	rm -rf $(BUILD_DIR)
