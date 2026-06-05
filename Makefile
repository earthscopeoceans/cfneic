FC = gfortran
FFLAGS ?= -g
BUILD_DIR ?= build
VERIFY_BASELINE ?= tests/fixtures/legacy_outputs
VERIFY_INPUT ?= /Users/jdsimon/mermaid/cfneic/inputs
VERIFY_OUT ?=
VERIFY_RDGPS_OUT ?=
VERIFY_NEIC_OUT ?=

.PHONY: all verify-legacy-outputs verify-rdgps-fixtures verify-neic-legacy-behavior clean

all: $(BUILD_DIR)/cfneic $(BUILD_DIR)/rdGPS

$(BUILD_DIR):
	mkdir -p $@

# Source order mirrors the legacy command:
# gfortran -g -o $root/cfneic mod_ttak135.f90 timedel.f90 cfneic.f90
$(BUILD_DIR)/cfneic: mod_ttak135.f90 timedel.f90 cfneic.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -o $@ mod_ttak135.f90 timedel.f90 cfneic.f90

$(BUILD_DIR)/rdGPS: rdGPS.f90 timedel.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -o $@ rdGPS.f90 timedel.f90

verify-legacy-outputs: all
	BASELINE_ROOT="$(VERIFY_BASELINE)" INPUT_ROOT="$(VERIFY_INPUT)" VERIFY_OUT="$(VERIFY_OUT)" ./verify_legacy_outputs

verify-rdgps-fixtures: all
	VERIFY_RDGPS_OUT="$(VERIFY_RDGPS_OUT)" ./verify_rdgps_fixtures

verify-neic-legacy-behavior: all
	VERIFY_NEIC_OUT="$(VERIFY_NEIC_OUT)" ./verify_neic_legacy_behavior

clean:
	rm -rf $(BUILD_DIR)
