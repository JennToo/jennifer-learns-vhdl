SRCS     := $(shell find . -name '*.vhd')
OUTPUTS  := $(SRCS:.vhd=.o)
SIMS     := tb_spi_rx
SIM_RUNS := $(SIMS:=-run)

.PHONY: all clean $(SIM_RUNS)

all: $(SIM_RUNS)

$(SIM_RUNS): %-run: %
	ghdl -r $< --wave=$<.ghw --assert-level=note

$(OUTPUTS): %.o: %.vhd
	ghdl -a -Wall $<

$(SIMS): %: $(OUTPUTS)
	ghdl -e $@

clean:
	rm *.o $(SIMS) *.cf *.lst
