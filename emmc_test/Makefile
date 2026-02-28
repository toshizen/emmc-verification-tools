TOP_DIR := $(shell cd ../../../; pwd)
include $(TOP_DIR)/config.mak

APPS = emmc_test

OBJS	:= $(shell find -type f -name "*.c" | sed -e 's/\.c/\.o/g')
LDFLAGS += -pthread
DEFINES +=

all: $(APPS)

$(APPS): $(OBJS)
	$(CC) -o $(APPS) $(shell find -type f -name "*.o") $(OFLAGS) $(LDFLAGS) $(EXTRALIBS) $(LDLIBS)
	@if [ -n "$(OBJ_DIR)" ]; then \
		if [ ! -d $(OBJ_DIR) ]; \
			then mkdir -p $(OBJ_DIR); \
		fi; \
		if [ -e $(APPS) ]; \
			then cp -afp $(APPS) $(OBJ_DIR)/$(APPS); \
		fi \
	fi

%.o: %.c
	$(CC) $(DEFINES) $(CFLAGS) $(INCDIR) -c -o $@ $<

clean:
	rm -f *~ *.o

distclean:
	rm -f *~ *.o $(APPS)

install:
	mkdir -p $(INSTDIR)/bin
	cp $(APPS) $(INSTDIR)/bin/.
