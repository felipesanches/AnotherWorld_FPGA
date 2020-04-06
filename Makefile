# ******* project, board and chip name *******
PROJECT = anotherworld
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = 12
FPGA_PACKAGE = CABGA381

# ******* if programming with OpenOCD *******
# using local latest openocd until in linux distribution
OPENOCD=openocd_ft232r
# default onboard usb-jtag
OPENOCD_INTERFACE=$(SCRIPTS)/ft231x.ocd
# ulx3s-jtag-passthru
#OPENOCD_INTERFACE=$(SCRIPTS)/ft231x2.ocd
# ulx2s
#OPENOCD_INTERFACE=$(SCRIPTS)/ft232r.ocd
# external jtag
#OPENOCD_INTERFACE=$(SCRIPTS)/ft2232.ocd

# ******* design files *******
CONSTRAINTS = ulx3s_v20.lpf
TOP_MODULE = anotherworld_cpu
TOP_MODULE_FILE = hdl/$(TOP_MODULE).v

CLK0_NAME = clk_25_250_125_25
CLK0_FILE_NAME = clocks/$(CLK0_NAME).v
CLK0_OPTIONS = \
  --module=$(CLK0_NAME) \
  --clkin_name=clki \
  --clkin=25 \
  --clkout0_name=clko \
  --clkout0=250 \
  --clkout1_name=clks1 \
  --clkout1=125 \
  --clkout2_name=clks2 \
  --clkout2=25

VERILOG_FILES = \
  $(TOP_MODULE_FILE) \
  $(CLK0_FILE_NAME) \
  hdl/fake_differential.v \
  hdl/hvsync_generator.v

# *.vhd those files will be converted to *.v files with vhdl2vl (warning overwriting/deleting)
VHDL_FILES = \
  hdl/vga2dvid.vhd \
  hdl/tmds_encoder.vhd

# synthesis options
#YOSYS_OPTIONS = -noccu2

SCRIPTS = scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/trellis_main.mk
