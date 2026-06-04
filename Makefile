FC = gfortran
FFLAGS ?= -g
BUILD_DIR ?= build
ROOT ?= /Users/jdsimon/mermaid/cfneic

.PHONY: all install clean

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

$(ROOT)/cfneic: mod_ttak135.f90 timedel.f90 cfneic.f90
	$(FC) $(FFLAGS) -o $@ mod_ttak135.f90 timedel.f90 cfneic.f90

$(ROOT)/rdGPS: rdGPS.f90 timedel.f90
	$(FC) $(FFLAGS) -o $@ rdGPS.f90 timedel.f90

clean:
	rm -rf $(BUILD_DIR)
