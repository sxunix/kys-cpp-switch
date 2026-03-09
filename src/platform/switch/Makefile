#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

#---------------------------------------------------------------------------------
# kys-cpp Switch port
#---------------------------------------------------------------------------------
ROOT_DIR    := ../../..
ABS_ROOT    ?= $(abspath $(ROOT_DIR))
SRC_DIR     := $(ROOT_DIR)/src
MLCC_DIR    := $(ROOT_DIR)/mlcc
OTHERS_DIR  := $(ROOT_DIR)/others

TARGET      := kys
BUILD       := bin
SOURCES     := $(SRC_DIR) $(MLCC_DIR) $(OTHERS_DIR)
LOCAL_PREFIX := $(ROOT_DIR)/local/switch
INCLUDES    := $(ROOT_DIR)/include $(SRC_DIR) $(MLCC_DIR) $(OTHERS_DIR) $(LOCAL_PREFIX)/include

APP_TITLE   := 金庸群侠传
APP_AUTHOR  := scarsty & sxunix
APP_VERSION := 0.4-switch

#---------------------------------------------------------------------------------
# Collect source files
#---------------------------------------------------------------------------------
CPPFILES    := $(notdir $(wildcard $(SRC_DIR)/*.cpp)) \
               Hanz2Piny.cpp \
               filefunc.cpp strfunc.cpp PotConv.cpp

CFILES      := zip.c

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
ARCH    := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE

CFLAGS  := -g -Wall -O2 -ffunction-sections \
           $(ARCH) $(DEFINES) \
           -D__SWITCH__ -DUSE_SDL_MIXER_AUDIO -DWITHOUT_OPENCC \
           -Wno-parentheses -Wno-sign-compare -Wno-unused-variable \
           -Wno-unused-but-set-variable -Wno-narrowing

CFLAGS  += $(INCLUDE) `$(PREFIX)pkg-config --cflags sdl2 SDL2_ttf SDL2_image SDL2_mixer`

CXXFLAGS := $(CFLAGS) -std=gnu++23 -Wno-reorder -include climits

ASFLAGS := -g $(ARCH)
LDFLAGS  = -specs=$(DEVKITPRO)/libnx/switch.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map)

LIBS    := -lSDL2_mixer -lSDL2_ttf -lSDL2_image \
           `$(PREFIX)pkg-config --libs sdl2` \
           -lmpg123 -lmodplug -lopusfile -lopus -lvorbisidec -logg -lFLAC \
           -lfreetype -lharfbuzz -lfreetype -lpng -ljpeg -lwebp -lbz2 -lz \
           -llua -lsqlite3 -lyaml-cpp -liconv \
           -lnx -lm

#---------------------------------------------------------------------------------
# list of directories containing libraries
#---------------------------------------------------------------------------------
LIBDIRS := $(CURDIR)/$(LOCAL_PREFIX) $(PORTLIBS) $(LIBNX)

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT   := $(CURDIR)/$(TARGET)
export TOPDIR   := $(CURDIR)
export ABS_ROOT

export VPATH    := $(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
                   $(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR  := $(CURDIR)/$(BUILD)

BINFILES :=

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
export LD := $(CXX)

export OFILES_BIN   := $(addsuffix .o,$(BINFILES))
export OFILES_SRC   := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o)
export OFILES       := $(OFILES_BIN) $(OFILES_SRC)
export HFILES_BIN   := $(addsuffix .h,$(subst .,_,$(BINFILES)))

export INCLUDE  := $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
                   $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
                   -I$(CURDIR)/$(BUILD)

export LIBPATHS := $(foreach dir,$(LIBDIRS),-L$(dir)/lib)

ifeq ($(strip $(CONFIG_JSON)),)
    jsons := $(wildcard *.json)
    ifneq (,$(findstring $(TARGET).json,$(jsons)))
        export APP_JSON := $(TOPDIR)/$(TARGET).json
    else
        ifneq (,$(findstring config.json,$(jsons)))
            export APP_JSON := $(TOPDIR)/config.json
        endif
    endif
else
    export APP_JSON := $(TOPDIR)/$(CONFIG_JSON)
endif

ifeq ($(strip $(ICON)),)
    icons := $(wildcard *.jpg)
    ifneq (,$(findstring $(TARGET).jpg,$(icons)))
        export APP_ICON := $(TOPDIR)/$(TARGET).jpg
    else
        ifneq (,$(findstring icon.jpg,$(icons)))
            export APP_ICON := $(TOPDIR)/icon.jpg
        endif
    endif
else
    export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_ICON)),)
    export NROFLAGS += --icon=$(APP_ICON)
endif

ifeq ($(strip $(NO_NACP)),)
    export NROFLAGS += --nacp=$(CURDIR)/$(TARGET).nacp
endif

ifneq ($(APP_TITLEID),)
    export NACPFLAGS += --titleid=$(APP_TITLEID)
endif

ifneq ($(ROMFS),)
    export NROFLAGS += --romfsdir=$(CURDIR)/$(ROMFS)
endif

.PHONY: $(BUILD) clean all

all: $(BUILD)

$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

clean:
	@echo clean ...
ifeq ($(strip $(APP_JSON)),)
	@rm -fr $(BUILD) $(TARGET).nro $(TARGET).nacp $(TARGET).elf
else
	@rm -fr $(BUILD) $(TARGET).nsp $(TARGET).nso $(TARGET).npdm $(TARGET).elf
endif

#---------------------------------------------------------------------------------
else
.PHONY: all

DEPENDS := $(OFILES:.o=.d)

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
ifeq ($(strip $(APP_JSON)),)

all: $(OUTPUT).nro

ifeq ($(strip $(NO_NACP)),)
$(OUTPUT).nro : $(OUTPUT).elf $(OUTPUT).nacp
else
$(OUTPUT).nro : $(OUTPUT).elf
endif

else

all: $(OUTPUT).nsp

$(OUTPUT).nsp : $(OUTPUT).nso $(OUTPUT).npdm
$(OUTPUT).nso : $(OUTPUT).elf

endif

$(OUTPUT).elf : $(OFILES)

$(OFILES_SRC) : $(HFILES_BIN)

#---------------------------------------------------------------------------------
%.bin.o %_bin.h : %.bin
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

-include $(DEPENDS)

#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
