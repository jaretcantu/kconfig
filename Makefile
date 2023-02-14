# SPDX-License-Identifier: GPL-2.0

# The following bits are from scripts/Kbuild.include

CONFIG_SHELL:=sh

# Convenient variables
comma   := ,
quote   := "
squote  := '
empty   :=
space   := $(empty) $(empty)
space_escape := _-_SPACE_-_
pound := \#

###
# Name of target with a '.' as filename prefix. foo/bar.o => foo/.bar.o
dot-target = $(dir $@).$(notdir $@)

###
# The temporary file to save gcc -MMD generated dependencies must not
# contain a comma
depfile = $(subst $(comma),_,$(dot-target).d)

# Useful for describing the dependency of composite objects
# Usage:
#   $(call multi_depend, multi_used_targets, suffix_to_remove, suffix_to_add)
define multi_depend
$(foreach m, $(notdir $1), \
	$(eval $(obj)/$m: \
	$(addprefix $(obj)/, $(foreach s, $3, $($(m:%$(strip $2)=%$(s)))))))
endef

# Useful for describing the dependency of composite objects
# Usage:
#   $(call multi_depend, multi_used_targets, suffix_to_remove, suffix_to_add)
define multi_depend
$(foreach m, $(notdir $1), \
	$(eval $(obj)/$m: \
	$(addprefix $(obj)/, $(foreach s, $3, $($(m:%$(strip $2)=%$(s)))))))
endef

# target with $(obj)/ and its suffix stripped
target-stem = $(basename $(patsubst $(obj)/%,%,$@))

# Set up make environment like a kernel build.
obj := .
src := .
srctree := .

HOSTCC ?= gcc
HOSTCXX ?= g++

# ===========================================================================
# Kernel configuration targets
# These targets are used from top-level makefile

PHONY += xconfig gconfig menuconfig config localmodconfig localyesconfig \
	build_menuconfig build_nconfig build_gconfig build_xconfig

ifdef KBUILD_KCONFIG
Kconfig := $(KBUILD_KCONFIG)
else
Kconfig := Kconfig
endif

ifeq ($(quiet),silent_)
silent := -s
endif

# We need this, in case the user has it in its environment
unexport CONFIG_

xconfig: $(obj)/qconf
	$(Q)$(obj)/qconf $(silent) $(Kconfig)

gconfig: $(obj)/gconf
	$(Q)$(obj)/gconf $(silent) $(Kconfig)

menuconfig: $(obj)/mconf
	$(Q)$(obj)/mconf $(silent) $(Kconfig)

config: $(obj)/conf
	$(Q)$(obj)/conf $(silent) --oldaskconfig $(Kconfig)

nconfig: $(obj)/nconf
	$(Q)$(obj)/nconf $(silent) $(Kconfig)

build_menuconfig: $(obj)/mconf

build_nconfig: $(obj)/nconf

build_gconfig: $(obj)/gconf

build_xconfig: $(obj)/qconf

localyesconfig localmodconfig: $(obj)/conf
	$(Q)$(PERL) $(srctree)/$(src)/streamline_config.pl --$@ $(srctree) $(Kconfig) > .tmp.config
	$(Q)if [ -f .config ]; then 				\
		cmp -s .tmp.config .config ||			\
		(mv -f .config .config.old.1;			\
		 mv -f .tmp.config .config;			\
		 $(obj)/conf $(silent) --oldconfig $(Kconfig);		\
		 mv -f .config.old.1 .config.old)		\
	else							\
		mv -f .tmp.config .config;			\
		$(obj)/conf $(silent) --oldconfig $(Kconfig);		\
	fi
	$(Q)rm -f .tmp.config

# These targets map 1:1 to the commandline options of 'conf'
#
# Note:
#  syncconfig has become an internal implementation detail and is now
#  deprecated for external use
simple-targets := oldconfig allnoconfig allyesconfig allmodconfig \
	alldefconfig randconfig listnewconfig olddefconfig syncconfig \
	helpnewconfig yes2modconfig mod2yesconfig

PHONY += $(simple-targets)

$(simple-targets): $(obj)/conf
	$(Q)$(obj)/conf $(silent) --$@ $(Kconfig)

PHONY += savedefconfig defconfig

savedefconfig: $(obj)/conf
	$(Q)$< $(silent) --$@=defconfig $(Kconfig)

defconfig: $(obj)/conf
ifneq ($(wildcard $(srctree)/arch/$(SRCARCH)/configs/$(KBUILD_DEFCONFIG)),)
	@$(kecho) "*** Default configuration is based on '$(KBUILD_DEFCONFIG)'"
	$(Q)$< $(silent) --defconfig=arch/$(SRCARCH)/configs/$(KBUILD_DEFCONFIG) $(Kconfig)
else
	@$(kecho) "*** Default configuration is based on target '$(KBUILD_DEFCONFIG)'"
	$(Q)$(MAKE) -f $(srctree)/Makefile $(KBUILD_DEFCONFIG)
endif

%_defconfig: $(obj)/conf
	$(Q)$< $(silent) --defconfig=arch/$(SRCARCH)/configs/$@ $(Kconfig)

configfiles=$(wildcard $(srctree)/kernel/configs/$@ $(srctree)/arch/$(SRCARCH)/configs/$@)

%.config: $(obj)/conf
	$(if $(call configfiles),, $(error No configuration exists for this target on this architecture))
	$(Q)$(CONFIG_SHELL) $(srctree)/merge_config.sh -m .config $(configfiles)
	$(Q)$(MAKE) -f $(srctree)/Makefile olddefconfig

PHONY += kvmconfig
kvmconfig: kvm_guest.config
	@echo >&2 "WARNING: 'make $@' will be removed after Linux 5.10"
	@echo >&2 "         Please use 'make $<' instead."

PHONY += xenconfig
xenconfig: xen.config
	@echo >&2 "WARNING: 'make $@' will be removed after Linux 5.10"
	@echo >&2 "         Please use 'make $<' instead."

PHONY += tinyconfig
tinyconfig:
	$(Q)$(MAKE) -f $(srctree)/Makefile allnoconfig tiny.config

# CHECK: -o cache_dir=<path> working?
PHONY += testconfig
testconfig: $(obj)/conf
	$(Q)$(PYTHON3) -B -m pytest $(srctree)/$(src)/tests \
	-o cache_dir=$(abspath $(obj)/tests/.cache) \
	$(if $(findstring 1,$(KBUILD_VERBOSE)),--capture=no)
clean-files += tests/.cache

# Help text used by make help
help:
	@echo  '  config	  - Update current config utilising a line-oriented program'
	@echo  '  nconfig         - Update current config utilising a ncurses menu based program'
	@echo  '  menuconfig	  - Update current config utilising a menu based program'
	@echo  '  xconfig	  - Update current config utilising a Qt based front-end'
	@echo  '  gconfig	  - Update current config utilising a GTK+ based front-end'
	@echo  '  oldconfig	  - Update current config utilising a provided .config as base'
	@echo  '  localmodconfig  - Update current config disabling modules not loaded'
	@echo  '                    except those preserved by LMC_KEEP environment variable'
	@echo  '  localyesconfig  - Update current config converting local mods to core'
	@echo  '                    except those preserved by LMC_KEEP environment variable'
	@echo  '  defconfig	  - New config with default from ARCH supplied defconfig'
	@echo  '  savedefconfig   - Save current config as ./defconfig (minimal config)'
	@echo  '  allnoconfig	  - New config where all options are answered with no'
	@echo  '  allyesconfig	  - New config where all options are accepted with yes'
	@echo  '  allmodconfig	  - New config selecting modules when possible'
	@echo  '  alldefconfig    - New config with all symbols set to default'
	@echo  '  randconfig	  - New config with random answer to all options'
	@echo  '  yes2modconfig	  - Change answers from yes to mod if possible'
	@echo  '  mod2yesconfig	  - Change answers from mod to yes if possible'
	@echo  '  listnewconfig   - List new options'
	@echo  '  helpnewconfig   - List new options and help text'
	@echo  '  olddefconfig	  - Same as oldconfig but sets new symbols to their'
	@echo  '                    default value without prompting'
	@echo  '  tinyconfig	  - Configure the tiniest possible kernel'
	@echo  '  testconfig	  - Run Kconfig unit tests (requires python3 and pytest)'

# ===========================================================================
# object files used by all kconfig flavours
common-objs	:= confdata.o expr.o lexer.lex.o parser.tab.o preprocess.o \
		   symbol.o util.o

$(obj)/lexer.lex.o: $(obj)/parser.tab.h
HOSTCFLAGS_lexer.lex.o	:= -I $(srctree)/$(src)
HOSTCFLAGS_parser.tab.o	:= -I $(srctree)/$(src)

# conf: Used for defconfig, oldconfig and related targets
hostprogs	+= conf
conf-objs	:= conf.o $(common-objs)

# nconf: Used for the nconfig target based on ncurses
hostprogs	+= nconf
nconf-objs	:= nconf.o nconf.gui.o $(common-objs)

HOSTLDLIBS_nconf	= $(shell . $(obj)/nconf-cfg && echo $$libs)
HOSTCFLAGS_nconf.o	= $(shell . $(obj)/nconf-cfg && echo $$cflags)
HOSTCFLAGS_nconf.gui.o	= $(shell . $(obj)/nconf-cfg && echo $$cflags)

$(obj)/nconf.o $(obj)/nconf.gui.o: $(obj)/nconf-cfg

# mconf: Used for the menuconfig target based on lxdialog
hostprogs	+= mconf
lxdialog	:= $(addprefix lxdialog/, \
		     checklist.o inputbox.o menubox.o textbox.o util.o yesno.o)
mconf-objs	:= mconf.o $(lxdialog) $(common-objs)

HOSTLDLIBS_mconf = $(shell . $(obj)/mconf-cfg && echo $$libs)
$(foreach f, mconf.o $(lxdialog), \
  $(eval HOSTCFLAGS_$f = $$(shell . $(obj)/mconf-cfg && echo $$$$cflags)))

$(addprefix $(obj)/, mconf.o $(lxdialog)): $(obj)/mconf-cfg

# qconf: Used for the xconfig target based on Qt
hostprogs	+= qconf
qconf-cxxobjs	:= qconf.o qconf-moc.o
qconf-objs	:= images.o $(common-objs)

HOSTLDLIBS_qconf	= $(shell . $(obj)/qconf-cfg && echo $$libs)
HOSTCXXFLAGS_qconf.o	= $(shell . $(obj)/qconf-cfg && echo $$cflags)
HOSTCXXFLAGS_qconf-moc.o = $(shell . $(obj)/qconf-cfg && echo $$cflags)

$(obj)/qconf.o: $(obj)/qconf-cfg

quiet_cmd_moc = MOC     $@
      cmd_moc = $(shell . $(obj)/qconf-cfg && echo $$moc) $< -o $@

$(obj)/qconf-moc.cc: $(src)/qconf.h $(obj)/qconf-cfg FORCE
	$(cmd_moc)

targets += qconf-moc.cc

# gconf: Used for the gconfig target based on GTK+
hostprogs	+= gconf
gconf-objs	:= gconf.o images.o $(common-objs)

HOSTLDLIBS_gconf    = $(shell . $(obj)/gconf-cfg && echo $$libs)
HOSTCFLAGS_gconf.o  = $(shell . $(obj)/gconf-cfg && echo $$cflags)

$(obj)/gconf.o: $(obj)/gconf-cfg

# check if necessary packages are available, and configure build flags
$(obj)/%conf-cfg: $(src)/%conf-cfg.sh FORCE
	$(CONFIG_SHELL) $< > $@

clean-files += *conf-cfg

# LEX
# ---------------------------------------------------------------------------
quiet_cmd_flex = LEX     $@
      cmd_flex = $(LEX) -o$@ -L $<

$(obj)/%.lex.c: $(src)/%.l FORCE
	$(cmd_flex)

# YACC
# ---------------------------------------------------------------------------
quiet_cmd_bison = YACC    $(basename $@).[ch]
      cmd_bison = $(YACC) -o $(basename $@).c --defines=$(basename $@).h -t -l $<

$(obj)/%.tab.c $(obj)/%.tab.h: $(src)/%.y FORCE
	$(cmd_bison)

# ==========================================================================
# Building binaries on the host system
# Binaries are used during the compilation of the kernel, for example
# to preprocess a data file.
#
# Both C and C++ are supported, but preferred language is C for such utilities.
#
# Sample syntax (see Documentation/kbuild/makefiles.rst for reference)
# hostprogs := bin2hex
# Will compile bin2hex.c and create an executable named bin2hex
#
# hostprogs     := lxdialog
# lxdialog-objs := checklist.o lxdialog.o
# Will compile lxdialog.c and checklist.c, and then link the executable
# lxdialog, based on checklist.o and lxdialog.o
#
# hostprogs       := qconf
# qconf-cxxobjs   := qconf.o
# qconf-objs      := menu.o
# Will compile qconf as a C++ program, and menu as a C program.
# They are linked as C++ code to the executable qconf

# C code
# Executables compiled from a single .c file
host-csingle	:= $(foreach m,$(hostprogs), \
			$(if $($(m)-objs)$($(m)-cxxobjs),,$(m)))

# C executables linked based on several .o files
host-cmulti	:= $(foreach m,$(hostprogs),\
		   $(if $($(m)-cxxobjs),,$(if $($(m)-objs),$(m))))

# Object (.o) files compiled from .c files
host-cobjs	:= $(sort $(foreach m,$(hostprogs),$($(m)-objs)))

# C++ code
# C++ executables compiled from at least one .cc file
# and zero or more .c files
host-cxxmulti	:= $(foreach m,$(hostprogs),$(if $($(m)-cxxobjs),$(m)))

# C++ Object (.o) files compiled from .cc files
host-cxxobjs	:= $(sort $(foreach m,$(host-cxxmulti),$($(m)-cxxobjs)))

host-csingle	:= $(addprefix $(obj)/,$(host-csingle))
host-cmulti	:= $(addprefix $(obj)/,$(host-cmulti))
host-cobjs	:= $(addprefix $(obj)/,$(host-cobjs))
host-cxxmulti	:= $(addprefix $(obj)/,$(host-cxxmulti))
host-cxxobjs	:= $(addprefix $(obj)/,$(host-cxxobjs))

#####
# Handle options to gcc. Support building with separate output directory

_hostc_flags   = $(KBUILD_HOSTCFLAGS)   $(HOST_EXTRACFLAGS)   \
                 $(HOSTCFLAGS_$(target-stem).o)
_hostcxx_flags = $(KBUILD_HOSTCXXFLAGS) $(HOST_EXTRACXXFLAGS) \
                 $(HOSTCXXFLAGS_$(target-stem).o)

# $(objtree)/$(obj) for including generated headers from checkin source files
ifeq ($(KBUILD_EXTMOD),)
ifdef building_out_of_srctree
_hostc_flags   += -I $(objtree)/$(obj)
_hostcxx_flags += -I $(objtree)/$(obj)
endif
endif

hostc_flags    = -Wp,-MMD,$(depfile) $(_hostc_flags)
hostcxx_flags  = -Wp,-MMD,$(depfile) $(_hostcxx_flags)

#####
# Compile programs on the host

# Create executable from a single .c file
# host-csingle -> Executable
quiet_cmd_host-csingle 	= HOSTCC  $@
      cmd_host-csingle	= $(HOSTCC) $(hostc_flags) $(KBUILD_HOSTLDFLAGS) -o $@ $< \
		$(KBUILD_HOSTLDLIBS) $(HOSTLDLIBS_$(target-stem))
$(host-csingle): $(obj)/%: $(src)/%.c FORCE
	$(cmd_host-csingle)

# Link an executable based on list of .o files, all plain c
# host-cmulti -> executable
quiet_cmd_host-cmulti	= HOSTLD  $@
      cmd_host-cmulti	= $(HOSTCC) $(KBUILD_HOSTLDFLAGS) -o $@ \
			  $(addprefix $(obj)/, $($(target-stem)-objs)) \
			  $(KBUILD_HOSTLDLIBS) $(HOSTLDLIBS_$(target-stem))
$(host-cmulti): FORCE
	$(cmd_host-cmulti)
$(call multi_depend, $(host-cmulti), , -objs)

# Create .o file from a single .c file
# host-cobjs -> .o
quiet_cmd_host-cobjs	= HOSTCC  $@
      cmd_host-cobjs	= $(HOSTCC) $(hostc_flags) -c -o $@ $<
$(host-cobjs): $(obj)/%.o: $(src)/%.c FORCE
	$(cmd_host-cobjs)

# Link an executable based on list of .o files, a mixture of .c and .cc
# host-cxxmulti -> executable
quiet_cmd_host-cxxmulti	= HOSTLD  $@
      cmd_host-cxxmulti	= $(HOSTCXX) $(KBUILD_HOSTLDFLAGS) -o $@ \
			  $(foreach o,objs cxxobjs,\
			  $(addprefix $(obj)/, $($(target-stem)-$(o)))) \
			  $(KBUILD_HOSTLDLIBS) $(HOSTLDLIBS_$(target-stem))
$(host-cxxmulti): FORCE
	$(cmd_host-cxxmulti)
$(call multi_depend, $(host-cxxmulti), , -objs -cxxobjs)

# Create .o file from a single .cc (C++) file
quiet_cmd_host-cxxobjs	= HOSTCXX $@
      cmd_host-cxxobjs	= $(HOSTCXX) $(hostcxx_flags) -c -o $@ $<
$(host-cxxobjs): $(obj)/%.o: $(src)/%.cc FORCE
	$(cmd_host-cxxobjs)

# Set up clean rules
.PHONY: clean distclean $(PHONY)

clean:
	$(Q)rm -f $(clean-files)
distclean: clean
	$(Q)rm -f $(lxdialog) $(conf-objs) $(mconf-objs) \
		$(qconf-cxxobjs) $(qconf-objs) $(gconf-objs) \
		conf gconf qconf mconf .depend

FORCE:
