#=====================================================================
#
# Toplevel makefile for OMNeT++ libraries and programs
#
#=====================================================================

include Makefile.inc

#=====================================================================
#
# Main targets
#
#=====================================================================


all: check-env components

components: base jnilibs samples


#=====================================================================
#
# OMNeT++ components
#
#=====================================================================

BASE=common layout eventlog scave nedxml sim envir cmdenv tkenv utils nedc
SAMPLES=aloha cqn dyna fifo hcube hist neddemo queuenet routing tictoc tokenring sockets
JNILIBS=org.omnetpp.ned.model  org.omnetpp.ide.nativelibs

#
# Group targets.
#
base: $(BASE)
jnilibs : $(JNILIBS)
samples: $(SAMPLES)

# dependencies (because of ver.h, tcl2c, opp_msgc, etc)
common layout eventlog scave nedxml sim envir cmdenv tkenv nedc makefiles: utils
layout eventlog scave nedxml sim envir cmdenv : common
nedc : nedxml
sim : nedc
makefiles: utils
$(SAMPLES) clean depend: makefiles

#
# Core libraries and programs
#
$(BASE):
	@echo ===== Compiling $@ ====
	cd $(OMNETPP_SRC_DIR)/$@ && $(MAKE)

#
# Native libs for the UI
#
$(JNILIBS):
	@echo ===== Compiling $@ ====
	cd $(OMNETPP_UI_DIR)/$@ && $(MAKE) clean
	cd $(OMNETPP_UI_DIR)/$@ && $(MAKE)

#
# Sample programs
#

$(SAMPLES):
	@echo ===== Compiling $@ ====
	cd $(OMNETPP_SAMPLES_DIR)/$@ && $(MAKE)

#
# Documentation
#
apis:
	cd $(OMNETPP_DOC_DIR)/src && $(MAKE) apis

docu:
	cd $(OMNETPP_DOC_DIR)/src && $(MAKE)

#
# Test
#
tests: check-env base
	cd $(OMNETPP_TEST_DIR) && $(MAKE)

#=====================================================================
#
# Utilities
#
#=====================================================================

check-env:
	@probefile=__probe__; \
	if (echo '' >$(OMNETPP_BIN_DIR)/$$probefile && \
	    chmod +x $(OMNETPP_BIN_DIR)/$$probefile) 2>/dev/null; then \
	  if $$probefile >/dev/null 2>/dev/null; then :; else \
	    echo '  *** Warning: $(OMNETPP_BIN_DIR) is not in the path, some components may not build!'; \
	  fi; \
	else \
	  echo '  *** Warning: Cannot write to $(OMNETPP_BIN_DIR), does it exist?'; \
	fi; \
	rm -f $(OMNETPP_BIN_DIR)/$$probefile; \
	if uname | grep "CYGWIN" >/dev/null; then :; else \
	  if echo $$LD_LIBRARY_PATH | grep "$(OMNETPP_LIB_DIR)" >/dev/null; then :; else \
	    echo '  *** Warning: Looks like $(OMNETPP_LIB_DIR) is not in LD_LIBRARY_PATH, shared libs may not work!'; \
	  fi; \
	fi

clean:
	for i in $(BASE); do \
	    (cd $(OMNETPP_SRC_DIR)/$$i && $(MAKE) clean); \
	done
	- rm $(OMNETPP_BIN_DIR)/*
	- rm $(OMNETPP_LIB_DIR)/*
	for i in $(SAMPLES); do \
	    (cd $(OMNETPP_SAMPLES_DIR)/$$i && $(MAKE) clean); \
	done
	cd $(OMNETPP_TEST_DIR) && $(MAKE) clean

depend:
	for i in $(BASE); do \
	    (cd $(OMNETPP_SRC_DIR)/$$i && $(MAKE) depend); \
	done
	for i in $(SAMPLES); do \
	    (cd $(OMNETPP_SAMPLES_DIR)/$$i && $(MAKE) depend); \
	done

makefiles:
	for i in $(SAMPLES); do \
	    (cd $(OMNETPP_SAMPLES_DIR)/$$i && (opp_makemake -f)); \
	done
	cd $(OMNETPP_SAMPLES_DIR)/queuenet/lib && (opp_makemake -f -o queuenet)
	cd $(OMNETPP_SAMPLES_DIR)/queuenet && (opp_makemake -f -r -n)

