# BSVTools library integration for BlueUART.
ifndef BLUEUART_MK_INCLUDED
BLUEUART_MK_INCLUDED := 1

BLUEUART_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BLUEUART_SRC := $(BLUEUART_ROOT)/hdl/src

# Prefer the project's libraries, falling back to bundled dependencies.
BLUEUART_BLUEAXI_MK := $(firstword $(wildcard $(CURDIR)/libraries/*/BlueAXI.mk) $(BLUEUART_ROOT)/dep/BlueAXI/BlueAXI.mk)
include $(BLUEUART_BLUEAXI_MK)
BLUEUART_BLUECSR_MK := $(firstword $(wildcard $(CURDIR)/libraries/*/BlueCSR.mk) $(BLUEUART_ROOT)/dep/bluecsr/BlueCSR.mk)
include $(BLUEUART_BLUECSR_MK)

EXTRA_BSV_LIBS += $(BLUEUART_SRC)

$(info Adding BlueUART from $(BLUEUART_SRC))

endif
