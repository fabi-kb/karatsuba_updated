library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;


-- the number of stages is (number of times until the Bits is <= 18)*11 + 3 
-- e.g. 72 -> 36 -> 18 ---> 2 Stages. This results in 22 + 3 Pipeline Stages


entity karatsuba_ram_based is
    Generic(
        Mbits : natural
    );
    Port (
        clk : in std_logic ;
        num : in unsigned (Mbits-1 downto 0) := (others => '0');
        num2 : in unsigned (Mbits-1 downto 0) := (others => '0');
        mult_out : out unsigned((2*Mbits)-1 downto 0) := (others => '0')
    );
end karatsuba_ram_based;

architecture Behavioral of karatsuba_ram_based is

    constant stages : integer := integer(log2(real(Mbits)))-4;

    constant addr_length: integer := 9;

    constant add_bits : integer := Mbits/2;

    --tmp signals    
    signal data_tmp : unsigned((2*addr_length)-1 downto 0) := (others => '0');
    signal addr_tmp: unsigned(addr_length-1 downto 0):= (others => '0');

    --output registers with shift registers 
    signal hi_mult_out, hi_mult_shift1, mid_mult_out, mid_mult_shift1,
 low_mult_out, low_mult_shift1 : unsigned(Mbits-1  downto 0) := (others => '0');

    --multiplication
    signal a0a0, a1a1: unsigned (Mbits-1 downto 0) := (others => '0');
    signal a1a0, tmp0: unsigned(Mbits+1 downto 0) := (others =>'0');
    signal tmp1, tmp1_reg, tmp2: unsigned((2*Mbits)-1 downto 0) := (others => '0');
    signal num_hi :  unsigned (add_bits-1 downto 0):= (others => '0');
    signal num_lo :  unsigned (add_bits-1 downto 0):= (others => '0');
    signal add_res: unsigned (add_bits downto 0):= (others => '0');

    -- registers for addition pipelining
    signal hi_num_reg,hi_num_reg2,hi_num_reg3 : unsigned (add_bits-1 downto 0):= (others => '0');
    signal lo_num_reg, lo_num_reg2,lo_num_reg3 : unsigned (add_bits-1 downto 0):= (others => '0');

    signal lo_add_num : unsigned ((Mbits/4) downto 0) := (others => '0');
    signal hi_shift,hi_lo_shift, lo_shift1: unsigned ((Mbits/4)-1 downto 0) := (others => '0');
    signal  hi_add : unsigned ((Mbits/4) downto 0) := (others => '0');

    -- signals for the carry and carry pipelining
    signal carry: std_logic := '0';
    signal carry_res: unsigned (add_bits-1 downto 0):= (others => '0');
    signal carry_add_res, carry_shift: unsigned (Mbits+1 downto 0):= (others => '0');

    --type std_logic_reg_type is array(natural range<>) of unsigned;
    signal carry_reg : unsigned (0 to (stages-1)*7 +5) :=(others => '0'); -- +3 for last Stage  

    type unsigned_reg is array (natural range<>) of unsigned;
    signal carry_add_reg: unsigned_reg (0 to (stages-1)*7 +4)(Mbits+1 downto 0) := (others => (others => '0'));

    --test registers for addition pipelining
    signal carrybit_shift : std_logic := '0';
begin

    karatsuba_breakdown :  if (Mbits > 9) generate

        lower :  entity work.karatsuba_ram_based
            generic map(
                Mbits => Mbits/2
            )
            port map(
                clk => clk,
                num => lo_num_reg3,
                num2 => lo_num_reg3,
                mult_out => low_mult_out
            );
        middle:  entity work.karatsuba_ram_based
            generic map(
                Mbits => Mbits/2
            )
            port map(
                clk => clk,
                num => add_res(add_bits-1 downto 0),
                num2 => add_res(add_bits-1 downto 0),
                mult_out => mid_mult_out
            );
        high :  entity work.karatsuba_ram_based
            generic map(
                Mbits => Mbits/2
            )
            port map(
                clk => clk,
                num =>  hi_num_reg3,
                num2 =>  hi_num_reg3,
                mult_out => hi_mult_out
            );
    else generate

        addr_tmp <= to_unsigned(0, addr_length -Mbits) & num;
        mult_out <= data_tmp ((2*Mbits)-1 downto 0);


        process(clk)
        begin
            if rising_edge(clk) then

            end if;

        end process;

        lookup : entity work.ram_mult_lookup
            generic map(
                addr_length => 9
            )
            port map(
                clk => clk,
                addr => addr_tmp,
                data_out => data_tmp
            );

    end generate;

    addition_pipeline : if Mbits > 18 generate
       
        num_hi<= num(Mbits-1 downto Mbits/2);
        num_lo <= num(add_bits -1 downto 0);

    p_even_addition: process (clk)
        begin
            if rising_edge(clk) then

                --pipeline addition:
                lo_add_num <=  '0' & num_hi(num_hi'length/2 -1 downto 0)+ num_lo(num_lo'length/2 -1 downto 0);
                hi_shift <= num_hi(num_hi'length -1 downto num_hi'length/2);
                hi_lo_shift <= num_lo(num_lo'length - 1 downto num_lo'length/2);

                hi_add <= '0' & hi_shift + hi_lo_shift + lo_add_num(lo_add_num'high);
                lo_shift1 <= lo_add_num(lo_add_num'length -2 downto 0);
                add_res <= hi_add & lo_shift1;


                -- pipeline input
                hi_num_reg <= num_hi;
                hi_num_reg2 <= hi_num_reg;
                hi_num_reg3 <= hi_num_reg2;

                lo_num_reg <= num_lo;
                lo_num_reg2 <= lo_num_reg;
                lo_num_reg3 <= lo_num_reg2;


                --carry pipelining 

                carry_reg <= hi_add(hi_add'high) & carry_reg(0 to carry_reg'length-2);
                carry <= carry_reg(carry_reg'length-1);

                carrybit_shift <= hi_add(hi_add'high);


                --carry calculation 

                carry_res <= carrybit_shift and add_res(add_bits-1 downto 0);


                carry_add_reg <= (to_unsigned(0, add_bits+1) & '0' & carry_res + carry_res) & carry_add_reg(0 to carry_add_reg'length-2);

                carry_add_res <= carry_add_reg(carry_add_reg'length-1);

                carry_shift <= to_unsigned(0, Mbits) & '0' & (carry and carry);

                --result calculation
                a0a0 <= low_mult_out;
                a1a0 <= shift_left(carry_shift, Mbits) + shift_left(carry_add_res, Mbits/2) + mid_mult_out;
                a1a1 <= hi_mult_out;

                tmp0 <= a1a0 - a1a1 - a0a0;
                tmp1 <= a1a1 & a0a0;
                tmp1_reg <= tmp1;
                tmp2 <=  to_unsigned(0, Mbits-2) & tmp0;
                mult_out <=  tmp1_reg + shift_left(tmp2 , add_bits);
            end if;

        end process;
    -- Hardcode 18 bit case for fewer pipeline stages

    elsif Mbits > 9 generate 
        
        num_hi<= num(Mbits-1 downto Mbits/2);
        num_lo <= num(add_bits -1 downto 0);
        
        p_18_bit : process(clk) 
        --variable carry_del : std_logic;
        --variable carry_res_del : unsigned(add_bits-1 downto 0);
        begin 
            if rising_edge(clk) then
                add_res <= '0' & num_hi + num_lo;

                hi_num_reg3 <= num_hi;
                lo_num_reg3 <= num_lo;

                -- carry calc 
                
                -- STEP 1 
                carry <= add_res(add_res'high);

                carry_res <= add_res(add_res'high) and add_res(add_bits-1 downto 0);
                
                -- STEP 2 (Delaying the signals to sync with the ram lookup)
                
                -- STEP 2

                carry_shift <= to_unsigned(0, Mbits) & '0' & (carry and carry);

                carry_add_res <= (to_unsigned(0, (Mbits/2)+1) & '0' & carry_res + carry_res);
                
                -- Shifting the result by one cycle
                low_mult_shift1 <= low_mult_out;

                mid_mult_shift1 <= mid_mult_out;

                hi_mult_shift1 <= hi_mult_out;


                -- Stitch result back together 
                a0a0 <= low_mult_shift1;
                a1a0 <= shift_left(carry_shift, Mbits) + shift_left(carry_add_res, Mbits/2) + mid_mult_shift1;
                a1a1 <= hi_mult_shift1;

                tmp0 <= a1a0 - a1a1 - a0a0;
                tmp1 <= a1a1 & a0a0;
                tmp1_reg <= tmp1;
                tmp2 <=  shift_left(to_unsigned(0, Mbits-2) & tmp0, Mbits/2);
                mult_out <=  (tmp1_reg(tmp1_reg'high downto Mbits/4) + tmp2(tmp2'high downto Mbits/4)) & tmp1_reg(Mbits/4 -1 downto 0);


            end if;
        end process;

    end generate addition_pipeline;



end Behavioral;