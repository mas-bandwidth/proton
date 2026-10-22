
obj-m += proton.o

# ZERO WARNINGS, AS ERRORS: proton.c and the vendored hydrogen.c compile under the
# strict set, and any warning fails the build. PROTON_WARNINGS_AS_ERRORS=0 keeps the
# warnings and drops only -Werror.
#
# The kernel's own headers are not ours and are not held to it. Kbuild names them
# with -I, so their inline functions and macros would report a thousand warnings
# against this module's flags. The -isystem lines below name the SAME directories,
# in the same order, as system directories: gcc then searches them in that order on
# the system chain (an -I that is also an -isystem is ignored) and reports nothing
# from inside them. Nothing else is exempted, and no warning is turned off.
PROTON_WARNINGS_AS_ERRORS ?= 1
ccflags-y += -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion \
	-Wcast-qual -Wformat=2 -Wundef -Wdouble-promotion
ifeq ($(PROTON_WARNINGS_AS_ERRORS),1)
ccflags-y += -Werror
endif
# Kbuild also force-includes linux/compiler_types.h by absolute path (-include), which
# no search directory can mark as a system header. It defines two GNU named variadic
# macros (`args...`), which -Wpedantic reports at their definition in that header.
# -Wno-variadic-macros is that one warning and nothing else: neither proton.c nor
# hydrogen.c defines a variadic macro.
ccflags-y += -Wno-variadic-macros
ccflags-y += -isystem $(srctree)/arch/$(SRCARCH)/include \
	-isystem $(objtree)/arch/$(SRCARCH)/include/generated \
	-isystem $(srctree)/include \
	-isystem $(objtree)/include \
	-isystem $(srctree)/arch/$(SRCARCH)/include/uapi \
	-isystem $(objtree)/arch/$(SRCARCH)/include/generated/uapi \
	-isystem $(srctree)/include/uapi \
	-isystem $(objtree)/include/generated/uapi

module: proton.h proton.c hydrogen.c hydrogen.h
	@echo building proton kernel module
	sudo cp /sys/kernel/btf/vmlinux /usr/lib/modules/`uname -r`/build/
	rm -f *.o
	rm -f *.ko
	make -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) modules
	sudo rmmod -f proton >/dev/null 2>&1; echo
	sudo insmod proton.ko; echo

# Compile only: no sudo, no insmod, no BTF copy. Builds against KDIR, which
# defaults to the running kernel's headers. This is what CI calls, and it is
# the target to reach for when you want to know whether it still compiles.
KDIR ?= /lib/modules/$(shell uname -r)/build

build: proton.h proton.c hydrogen.c hydrogen.h
	make -C $(KDIR) M=$(shell pwd) modules
