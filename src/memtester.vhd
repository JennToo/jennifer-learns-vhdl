library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi.all;

entity memtester is
    generic (
        words_to_cover : integer := 128
    );
    port(
        clk    : in std_logic;
        arst   : in std_logic;
        enable : in std_logic;

        axi_initiator : out axi4l_initiator_signals_t;
        axi_target    : in axi4l_target_signals_t;

        address : out std_logic_vector(31 downto 0);
        fault   : out std_logic
    );
end memtester;

architecture rtl of memtester is
    constant value : std_logic_vector(15 downto 0) := "1111000010100101";
    constant max_address : unsigned(31 downto 0) := to_unsigned(2 * words_to_cover, 32);

    type state_t is (
        state_write_address,
        state_write_data,
        state_write_response,
        state_read_address,
        state_read_response
    );

    signal current_address       : unsigned(31 downto 0);
    signal current_state         : state_t;
    signal found_fault           : std_logic;
begin

    axi_initiator.awprot <= (others => '0');
    axi_initiator.arprot <= (others => '0');
    axi_initiator.wstrb  <= (others => '1');
    axi_initiator.awaddr <= std_logic_vector(current_address);
    axi_initiator.araddr <= std_logic_vector(current_address);
    axi_initiator.wdata  <= value;

    address <= std_logic_vector(current_address);
    fault   <= found_fault;
    
    state_machine: process(clk, arst)
    begin
        if (arst = '0') then
            current_state <= state_write_address;
            current_address <= to_unsigned(0, 32);
            found_fault <= '0';
            axi_initiator.awvalid <= '1';
        elsif (rising_edge(clk) and enable = '1' and found_fault = '0') then
            case (current_state) is
                when state_write_address =>
                    if (axi_target.awready = '1') then
                        axi_initiator.awvalid <= '0';
                        axi_initiator.wvalid <= '1';
                        current_state <= state_write_data;
                    end if;
                when state_write_data =>
                    if (axi_target.wready = '1') then
                        axi_initiator.wvalid <= '0';
                        axi_initiator.bready <= '1';
                        current_state <= state_write_response;
                    end if;
                when state_write_response =>
                    if (axi_target.bvalid = '1') then
                        axi_initiator.bready <= '0';
                        axi_initiator.arvalid <= '1';
                        current_state <= state_read_address;

                        if (axi_target.bresp /= "00") then
                            found_fault <= '1';
                        end if;
                    end if;
                when state_read_address =>
                    if (axi_target.arready = '1') then
                        axi_initiator.arvalid <= '0';
                        axi_initiator.rready <= '1';
                        current_state <= state_read_response;
                    end if;
                when state_read_response =>
                    if (axi_target.arready = '1') then
                        axi_initiator.rready <= '0';
                        axi_initiator.awvalid <= '1';
                        current_state <= state_write_address;
                        if (axi_target.rresp /= "00") then
                            found_fault <= '1';
                        end if;
                        if (axi_target.rdata /= value) then
                            found_fault <= '1';
                        end if;
                        if (current_address = max_address) then
                            current_address <= to_unsigned(0, 32);
                        else
                            current_address <= current_address + 2;
                        end if;
                    end if;
            end case;

        end if;
    end process state_machine;

end rtl;
