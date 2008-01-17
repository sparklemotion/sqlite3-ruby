
SHELL = /bin/sh

#### Start of system configuration section. ####

srcdir = .
topdir = /opt/local/lib/ruby/1.8/i686-darwin8.10.1
hdrdir = $(topdir)
VPATH = $(srcdir):$(topdir):$(hdrdir)
prefix = $(DESTDIR)/opt/local
exec_prefix = $(DESTDIR)/opt/local
sitedir = $(prefix)/lib/ruby/site_ruby
rubylibdir = $(libdir)/ruby/$(ruby_version)
archdir = $(rubylibdir)/$(arch)
sbindir = $(exec_prefix)/sbin
vendordir = $(prefix)/lib/ruby/vendor_ruby
datadir = $(prefix)/share
includedir = $(prefix)/include
infodir = $(prefix)/info
sysconfdir = $(prefix)/etc
mandir = $(DESTDIR)/opt/local/share/man
libdir = $(DESTDIR)/opt/local/lib
sharedstatedir = $(prefix)/com
oldincludedir = $(DESTDIR)/usr/include
sitearchdir = $(sitelibdir)/$(sitearch)
vendorarchdir = $(vendorlibdir)/$(vendorarch)
bindir = $(exec_prefix)/bin
localstatedir = $(prefix)/var
vendorlibdir = $(vendordir)/$(ruby_version)
sitelibdir = $(sitedir)/$(ruby_version)
libexecdir = $(exec_prefix)/libexec

CC = gcc
LIBRUBY = $(LIBRUBY_SO)
LIBRUBY_A = lib$(RUBY_SO_NAME)-static.a
LIBRUBYARG_SHARED = -l$(RUBY_SO_NAME)
LIBRUBYARG_STATIC = -l$(RUBY_SO_NAME)-static

RUBY_EXTCONF_H = 
CFLAGS   =  -fno-common -O2  -fno-common -pipe -fno-common 
INCFLAGS = -I. -I. -I/opt/local/lib/ruby/1.8/i686-darwin8.10.1 -I.
CPPFLAGS = -DHAVE_SQLITE3_H -I/usr/local/include -I/opt/local/include
CXXFLAGS = $(CFLAGS) 
DLDFLAGS = -L/opt/local/lib  
LDSHARED = cc -dynamic -bundle -undefined suppress -flat_namespace
AR = ar
EXEEXT = 

RUBY_INSTALL_NAME = ruby
RUBY_SO_NAME = ruby
arch = i686-darwin8.10.1
sitearch = i686-darwin8.10.1
vendorarch = i686-darwin8.10.1
ruby_version = 1.8
ruby = /opt/local/bin/ruby
RUBY = $(ruby)
RM = rm -f
MAKEDIRS = mkdir -p
INSTALL = /usr/bin/install -c
INSTALL_PROG = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 644
COPY = cp

#### End of system configuration section. ####

preload = 

libpath = $(libdir) /usr/local/lib
LIBPATH =  -L"$(libdir)" -L"/usr/local/lib"
DEFFILE = 

CLEANFILES = 
DISTCLEANFILES = 

extout = 
extout_prefix = 
target_prefix = 
LOCAL_LIBS = 
LIBS = $(LIBRUBYARG_SHARED) -lsqlite3  -lpthread -ldl -lobjc  
SRCS = sqlite3_api_wrap.c
OBJS = sqlite3_api_wrap.o
TARGET = sqlite3_api
DLLIB = $(TARGET).bundle
EXTSTATIC = 
STATIC_LIB = 

RUBYCOMMONDIR = $(sitedir)$(target_prefix)
RUBYLIBDIR    = $(sitelibdir)$(target_prefix)
RUBYARCHDIR   = $(sitearchdir)$(target_prefix)

TARGET_SO     = $(DLLIB)
CLEANLIBS     = $(TARGET).bundle $(TARGET).il? $(TARGET).tds $(TARGET).map
CLEANOBJS     = *.o *.a *.s[ol] *.pdb *.exp *.bak

all:		$(DLLIB)
static:		$(STATIC_LIB)

clean:
		@-$(RM) $(CLEANLIBS) $(CLEANOBJS) $(CLEANFILES)

distclean:	clean
		@-$(RM) Makefile $(RUBY_EXTCONF_H) conftest.* mkmf.log
		@-$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)

realclean:	distclean
install: install-so install-rb

install-so: $(RUBYARCHDIR)
install-so: $(RUBYARCHDIR)/$(DLLIB)
$(RUBYARCHDIR)/$(DLLIB): $(DLLIB)
	$(INSTALL_PROG) $(DLLIB) $(RUBYARCHDIR)
install-rb: pre-install-rb install-rb-default
install-rb-default: pre-install-rb-default
pre-install-rb: Makefile
pre-install-rb-default: Makefile
$(RUBYARCHDIR):
	$(MAKEDIRS) $@

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

.SUFFIXES: .c .m .cc .cxx .cpp .C .o

.cc.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.cxx.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.cpp.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.C.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.c.o:
	$(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) -c $<

$(DLLIB): $(OBJS)
	@-$(RM) $@
	$(LDSHARED) $(DLDFLAGS) $(LIBPATH) -o $@ $(OBJS) $(LOCAL_LIBS) $(LIBS)



$(OBJS): ruby.h defines.h
