#   Makefile for Linux, FreeBSD, OpenBSD, and Darwin
#   Requirements: GNU Make, GCC 4.0 or later
#   Options: DESTDIR, PREFIX, DATAMODEL(ILP32/LP64)

PROG 	 = ypsilon

PREFIX 	 = /usr/local

CPPFLAGS = -DNDEBUG -DSYSTEM_SHARE_PATH='"$(DESTDIR)$(PREFIX)/share/$(PROG)"'

CXXFLAGS = -pipe -x c++ -pthread -O3 -fstrict-aliasing -fomit-frame-pointer -momit-leaf-frame-pointer

SRCS 	 = file.cpp main.cpp vm0.cpp object_heap_compact.cpp subr_flonum.cpp vm1.cpp object_set.cpp \
	   subr_hash.cpp vm2.cpp object_slab.cpp subr_list.cpp interpreter.cpp serialize.cpp \
           vm3.cpp port.cpp subr_others.cpp arith.cpp printer.cpp subr_port.cpp subr_r5rs_arith.cpp \
	   equiv.cpp reader.cpp ffi.cpp subr_base.cpp bag.cpp \
           subr_unicode.cpp hash.cpp subr_base_arith.cpp ucs4.cpp ioerror.cpp subr_bitwise.cpp utf8.cpp \
	   main.cpp subr_bvector.cpp violation.cpp object_factory.cpp \
           subr_ffi.cpp object_heap.cpp subr_fixnum.cpp bit.cpp list.cpp fasl.cpp socket.cpp subr_socket.cpp

VPATH 	 = src

UNAME 	 = $(shell uname -a)

ifndef DATAMODEL
  ifeq (, $(findstring x86_64, $(UNAME)))
    ifeq (, $(findstring amd64, $(UNAME)))
      DATAMODEL = ILP32
    else
      DATAMODEL = LP64
    endif
  else
    DATAMODEL = LP64
  endif
endif

ifneq (, $(findstring Linux, $(UNAME)))
  ifeq ($(shell $(CXX) -dumpspecs | grep 'march=native'), )
    ifeq ($(DATAMODEL), ILP32)  
      CXXFLAGS += -march=i686
    endif
  else
    CXXFLAGS += -march=native
  endif
  CXXFLAGS += -msse2 -mfpmath=sse
  ifeq ($(DATAMODEL), ILP32)  
    CPPFLAGS += -DDEFAULT_HEAP_LIMIT=32
    CXXFLAGS += -m32
    LDFLAGS = -m32
    ASFLAGS = --32
    SRCS += ffi_stub_linux.s
  else
    CPPFLAGS += -DDEFAULT_HEAP_LIMIT=64
    CXXFLAGS += -m64
    LDFLAGS = -m64
    ASFLAGS = --64
    SRCS += ffi_stub_linux64.s
  endif
  LDLIBS = -lpthread -ldl
endif

ifneq (, $(findstring FreeBSD, $(UNAME)))
  ifeq ($(shell $(CXX) -dumpspecs | grep 'march=native'), )
    ifeq ($(DATAMODEL), ILP32)  
      CXXFLAGS += -march=i686
    endif
  else
    CXXFLAGS += -march=native
  endif
  CPPFLAGS += -D__LITTLE_ENDIAN__
  CXXFLAGS += -msse2 -mfpmath=sse  
  ifeq ($(DATAMODEL), ILP32)  
    CPPFLAGS += -DDEFAULT_HEAP_LIMIT=32
    CXXFLAGS += -m32
    LDFLAGS = -m32
    ASFLAGS = --32
    SRCS += ffi_stub_freebsd.s
  else
    CPPFLAGS += -DDEFAULT_HEAP_LIMIT=64
    CXXFLAGS += -m64
    LDFLAGS = -m64
    ASFLAGS = --64
    SRCS += ffi_stub_freebsd64.s
  endif
  LDLIBS = -pthread
endif

ifneq (, $(findstring OpenBSD, $(UNAME)))
  ifeq ($(shell $(CXX) -dumpspecs | grep 'march=native'), )
    ifeq ($(DATAMODEL), ILP32)  
      CXXFLAGS += -march=i686
    endif
  else
    CXXFLAGS += -march=native
  endif
  CPPFLAGS += -D__LITTLE_ENDIAN__ -DNO_TLS
  CXXFLAGS += -msse2 -mfpmath=sse
  ifeq ($(DATAMODEL), ILP32)  
    CPPFLAGS += -DDEFAULT_HEAP_LIMIT=32
    CXXFLAGS += -m32
    LDFLAGS = -m32
    ASFLAGS = --32
    SRCS += ffi_stub_openbsd.s
  else
    CPPFLAGS += -DDEFAULT_HEAP_LIMIT=64
    CXXFLAGS += -m64
    LDFLAGS = -m64
    ASFLAGS = --64
    SRCS += ffi_stub_openbsd64.s
  endif
  LDLIBS = -pthread
endif

ifneq (, $(findstring Darwin, $(UNAME)))
  CXXFLAGS += -arch i386 -msse2 -mfpmath=sse
  CPPFLAGS += -DNO_TLS
  SRCS += ffi_stub_darwin.s
endif

OBJS =	$(patsubst %.cpp, %.o, $(filter %.cpp, $(SRCS))) $(patsubst %.s, %.o, $(filter %.s, $(SRCS)))
DEPS = 	$(patsubst %.cpp, %.d, $(filter %.cpp, $(SRCS)))

.PHONY: all install uninstall sitelib stdlib check bench clean distclean

all: $(PROG)
	@mkdir -p -m755 $(HOME)/.ypsilon

$(PROG): $(OBJS)
	$(CXX) $(LDFLAGS) $(LDLIBS) -o $@ $^

vm1.s: vm1.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) \
	-fno-reorder-blocks -fno-crossjumping -fno-align-labels -fno-align-loops -fno-align-jumps \
	-fverbose-asm -S src/vm1.cpp

vm1.o: vm1.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) \
	-fno-reorder-blocks -fno-crossjumping -fno-align-labels -fno-align-loops -fno-align-jumps \
	-c src/vm1.cpp

install: all stdlib sitelib
	mkdir -p -m755 $(DESTDIR)$(PREFIX)/bin
	mkdir -p -m755 $(DESTDIR)$(PREFIX)/share/man/man1
	cp $(PROG) $(DESTDIR)$(PREFIX)/bin/$(PROG)
	cp $(PROG).1 $(DESTDIR)$(PREFIX)/share/man/man1/$(PROG).1
	chmod 755 $(DESTDIR)$(PREFIX)/bin/$(PROG)
	chmod 644 $(DESTDIR)$(PREFIX)/share/man/man1/$(PROG).1

uninstall:
	-rm -rf $(DESTDIR)$(PREFIX)/share/$(PROG)/stdlib
	-rm -rf $(DESTDIR)$(PREFIX)/share/$(PROG)/sitelib
	-rm -f $(DESTDIR)$(PREFIX)/share/man/man1/$(PROG).1
	-rm -f $(DESTDIR)$(PREFIX)/bin/$(PROG)
	-rmdir $(DESTDIR)$(PREFIX)/share/$(PROG)

stdlib:
	mkdir -p -m755 $(DESTDIR)$(PREFIX)/share/$(PROG)/stdlib
	find stdlib -type f -name '*.scm' | cpio -pdu $(DESTDIR)$(PREFIX)/share/$(PROG)
	find $(DESTDIR)$(PREFIX)/share/$(PROG)/stdlib -type d -exec chmod 755 {} \;
	find $(DESTDIR)$(PREFIX)/share/$(PROG)/stdlib -type f -exec chmod 644 {} \;

sitelib:
	mkdir -p -m755 $(DESTDIR)$(PREFIX)/share/$(PROG)/sitelib
	find sitelib -type f -name '*.scm' | cpio -pdu $(DESTDIR)$(PREFIX)/share/$(PROG)
	find $(DESTDIR)$(PREFIX)/share/$(PROG)/sitelib -type d -exec chmod 755 {} \;
	find $(DESTDIR)$(PREFIX)/share/$(PROG)/sitelib -type f -exec chmod 644 {} \;

check: all
	@echo '----------------------------------------'
	@echo 'r4rstest.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/r4rstest.scm
	@echo '----------------------------------------'
	@echo 'tspl.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/tspl.scm
	@echo '----------------------------------------'
	@echo 'arith.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/arith.scm
	@echo '----------------------------------------'
	@echo 'r5rs_pitfall.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/r5rs_pitfall.scm
	@echo '----------------------------------------'
	@echo 'syntax-rule-stress-test.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/syntax-rule-stress-test.scm
	@echo '----------------------------------------'
	@echo 'r6rs.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/r6rs.scm
	@echo '----------------------------------------'
	@echo 'r6rs-lib.scm:'
	@./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib ./test/r6rs-lib.scm
	@echo '----------------------------------------'
	@echo 'Passed all tests'
	@rm -f ./test/tmp* 

eval: all
	./$(PROG) --acc=/tmp --sitelib=./sitelib:./stdlib

bench: all
	./$(PROG) --acc=/tmp --sitelib=./test:./sitelib:./stdlib -- bench/run-ypsilon.scm

clean:
	rm -f *.o *.d
	rm -f $(HOME)/.ypsilon/*.cache 
	rm -f $(HOME)/.ypsilon/*.time

distclean: clean
	rm -f tmp1 tmp2 tmp3 spheres.pgm
	find . -type f -name .DS_Store -print0 | xargs -0 rm -f
	find . -type f -name '*~' -print0 | xargs -0 rm -f
	rm -f ./test/tmp* 
	rm -f ./bench/gambit-benchmarks/tmp*
	rm -f ./bench/gambit-benchmarks/spheres.pgm
	rm -f -r ./build/* ./build-win32/* ./setup-win32/Debug ./setup-win32/Release
	rm -f ./ypsilon.xcodeproj/*.mode1v3 ./ypsilon.xcodeproj/*.pbxuser
	rm -f ./ypsilon.ncb
	rm -f ./ypsilon

%.d: %.cpp
	$(SHELL) -ec '$(CXX) -MM $(CPPFLAGS) $< \
	| sed '\''s/\($*\)\.o[ :]*/\1.o $@ : /g'\'' > $@; [ -s $@ ] || rm -f $@'

ifeq ($(findstring clean, $(MAKECMDGOALS)), )
  ifeq ($(findstring uninstall, $(MAKECMDGOALS)), )
    -include $(DEPS)
  endif
endif



