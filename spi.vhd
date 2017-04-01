library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi is
	Generic(  busWidth : natural := 16;  -- 16 bits de datos
				  clkDiv   : natural := 5    -- Divisor de reloj (clkDiv+1)*2 = 8 (SPICLK = 12.5 MHz) original 20
			); 

    Port ( 
			DATA0  : in   STD_LOGIC_VECTOR (7 downto 0); -- Datos que desean serializarse
			DATA1	 : in   STD_LOGIC_VECTOR (7 downto 0);
			DATA2	 : in   STD_LOGIC_VECTOR (7 downto 0);
			DATA3  : in   STD_LOGIC_VECTOR (7 downto 0);
			DATA4  : in   STD_LOGIC_VECTOR (7 downto 0);
			DATA5  : in   STD_LOGIC_VECTOR (7 downto 0);
			DATA6  : in   STD_LOGIC_VECTOR (7 downto 0);
			DATA7  : in   STD_LOGIC_VECTOR (7 downto 0);
         --Dach2 : in	STD_LOGIC_VECTOR (7 downto 0); --Datos para el canal 2
		   EN    : in   STD_LOGIC;  -- Con un flanco de subida, comienza la serializacion
         CLK   : in   STD_LOGIC;  -- CLK de entrada (100 MHz)
		   RST   : in   STD_LOGIC;  -- RST del sistema
		   EDGE  : in   STD_LOGIC;  -- Flanco de subida (1) o flanco de bajada (0)
         DONE  : out  STD_LOGIC;  -- Indica si ha finalizado la operacion
		   SDATA : out  STD_LOGIC;  -- Salida de datos SPI
         SCLK  : out  STD_LOGIC;  -- Salida de reloj SPI (12.5 MHz)
		   SCS2  : out	STD_LOGIC;  -- Salida Chip Select CH2
         SCS   : out  STD_LOGIC); -- Salida Chip Select CH1
end spi;

architecture Behavioral of spi is
	--type 	datos is array (7 downto 0) of std_logic_vector(15 downto 0);

	signal SPIClk     : STD_LOGIC; -- Salida del reloj SPI.
	signal CLKCounter : integer range 0 to clkDiv; -- Contador para realizar SCLK = CLK / 10
	signal dCount     : integer range 0 to busWidth; -- Contador para serializacion de datos
	signal dataTemp0 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp1 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp2 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp3 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp4 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp5 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp6 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTemp7 : STD_LOGIC_VECTOR (busWidth - 1 downto 0); -- Datos que ingresan al registro de corrimiento
	signal dataTempCh20 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh21 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh22 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh23 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh24: STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh25 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh26 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal dataTempCh27 : STD_LOGIC_VECTOR(buswidth -1 downto 0);--Datos del registro de corrimiento canal 2
	signal clkEN      : STD_LOGIC;  -- Habilita o deshabilita el reloj de salida SPI
	signal countD		: integer range 0 to 7;
	
	type FSM is (DATA_FETCH, SPICH10,SPICH11,SPICH12,SPICH13,SPICH14,SPICH15,SPICH16,SPICH17, SPICH20,
			SPICH21, SPICH22,SPICH23,SPICH24,SPICH25,SPICH26,SPICH27, RESYNC); -- Definicion de los estados de la FSM.
	signal currentState : FSM;         -- Senial del tipo FSM que controla el proceso.

begin

	process (CLK, RST) -- Aumenta el contador para el divisor del reloj, en base al reloj del sistema de 100MHz
	begin
		If (RST = '1') Then
			CLKCounter <= 0;  -- Si hay un reset, se inicializa en 0 el contador del divisor
			SPIClk <= '0';
		Else
			If (rising_edge(CLK)) Then
				If CLKCounter < clkDiv Then
					CLKCounter <= CLKCounter + 1; -- Si hay overflow, regresa a su valor inicial (0)
				Else
					CLKCounter <= 0;
					SPIClk <= not SPIClk; -- Si existio overflow en el contador de reloj secundario, genera una transicion en el reloj de SPI
				End If;
			End If;
		End If;
	end process;

	process (SPIClk, RST)  -- Si existe algun cambio en el reloj SPI, o Reset, cambiar la maquina de estados (FSM) currentState
	begin
		If (RST = '1') Then -- Durante reset
			clkEn  <= '0'; -- Deshabilitar el reloj de salida SPI 
			dCount <= 0;   -- Inicializar el contador del registro de corrimiento
			SCS    <= '1'; -- Inicializar CHIP-SELECT CHANNEL 1
			SCS2   <= '1'; -- Inicializar CHIP-SELECT CHANNEL 2
			SDATA  <= '0'; -- SALIDA CHANNEL 1
			-- SDAT2  <= '0'; -- SALIDA CHANNEL 2
			DONE   <= '0'; -- Inicializa la bandera de fin de operacion
			dataTemp0 <= (others => '0'); -- Vaciar los datos del registro de corrimiento
			dataTemp1 <= (others => '0');
			dataTemp2 <= (others => '0');
			dataTemp3 <= (others => '0');
			dataTemp4 <= (others => '0');
			dataTemp5 <= (others => '0');
			dataTemp6 <= (others => '0');
			dataTemp7 <= (others => '0');
			dataTempCh20 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh21 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh22 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh23 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh24 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh25 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh26 <= (others => '0'); --Se vacia los datos del registro
			dataTempCh27 <= (others => '0'); --Se vacia los datos del registro
			currentState <= DATA_FETCH;  -- Iniciar la FSM esperando datos
		Else
			If (rising_edge(SPIClk)) Then -- Cuando exista una transicion en el reloj SPI (12.5 MHz)
			
				Case currentState is
					When DATA_FETCH => -- El primer estado es leer lo que se va a serializar
						--DONE   <= '0';
						datatemp0 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA0))*65535/255, busWidth));
						dataTemp1 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA1))*65535/255, busWidth));
						datatemp2 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA2))*65535/255, busWidth));
						datatemp3 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA3))*65535/255, busWidth));
						datatemp4 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA4))*65535/255, busWidth));
						datatemp5 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA5))*65535/255, busWidth));
						datatemp6 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA6))*65535/255, busWidth));
						datatemp7 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA7))*65535/255, busWidth));
						dataTempCh20 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA0))*65535/255, busWidth));
						dataTempCh21 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA1))*65535/255, busWidth));
						dataTempCh22 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA2))*65535/255, busWidth));
						dataTempCh23 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA3))*65535/255, busWidth));
						dataTempCh24 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA4))*65535/255, busWidth));
						dataTempCh25 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA5))*65535/255, busWidth));
						dataTempCh26 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA6))*65535/255, busWidth));
						dataTempCh27 <= std_logic_vector(to_unsigned(to_integer(unsigned(DATA7))*65535/255, busWidth));
						If EN = '1' Then -- Cuando se registra la entrada de datos
							currentState <= SPICH10; -- Iniciar la serializacion
							SCS <= '0'; -- Habilitar el CHIP-SELECT SPI (activo bajo)
							DONE   <= '0';
						Else
							currentState <= DATA_FETCH; -- Si no, se queda esperando el ENABLE
						End If;
						
					When SPICH10 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp0(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp0 <= dataTemp0(busWidth - 2 downto 0) & dataTemp0(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH20; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH20 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh20(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh20 <= dataTempCh20(busWidth - 2 downto 0) & dataTempCh20(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS <= '0';
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH11; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH11 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp1(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp1 <= dataTemp1(busWidth - 2 downto 0) & dataTemp1(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH21; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH21 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh21(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh21 <= dataTempCh21(busWidth - 2 downto 0) & dataTempCh21(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS <= '0';
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH12; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH12 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp2(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp2 <= dataTemp2(busWidth - 2 downto 0) & dataTemp2(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH22; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH22 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh22(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh22 <= dataTempCh22(busWidth - 2 downto 0) & dataTempCh22(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS  <= '0'; 
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH13; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH13 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp3(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp3 <= dataTemp3(busWidth - 2 downto 0) & dataTemp3(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH23; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH23 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh23(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh23 <= dataTempCh23(busWidth - 2 downto 0) & dataTempCh23(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS  <= '0';
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH14; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH14 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp4(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp4 <= dataTemp4(busWidth - 2 downto 0) & dataTemp4(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH24; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH24 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh24(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh24 <= dataTempCh24(busWidth - 2 downto 0) & dataTempCh24(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH15; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH15 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp5(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp5 <= dataTemp5(busWidth - 2 downto 0) & dataTemp5(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH25; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH25 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh25(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh25 <= dataTempCh25(busWidth - 2 downto 0) & dataTempCh25(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS  <= '0';
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH16; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH16 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp6(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp6 <= dataTemp6(busWidth - 2 downto 0) & dataTemp6(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH26; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH26 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh26(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh26 <= dataTempCh26(busWidth - 2 downto 0) & dataTempCh26(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS  <= '0';
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH17; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
						When SPICH17 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTemp7(busWidth - 1);  -- Se toma el bit mas significativo
							dataTemp7 <= dataTemp7(busWidth - 2 downto 0) & dataTemp7(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS  <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							SCS2 <= '0';
							-- clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							--DONE   <= '0'; -- Ha finalizado la operacion de serializacion
							currentState <= SPICH27; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When SPICH27 =>
						If dCount < busWidth Then
							clkEn <= '1'; -- Habilitar el reloj de salida SPI
							SDATA <= dataTempCh27(busWidth - 1);  -- Se toma el bit mas significativo
							dataTempCh27 <= dataTempCh27(busWidth - 2 downto 0) & dataTempCh27(busWidth - 1); -- Y se realiza el corrimiento de un bit a la izquierda
							dCount <= dCount + 1;  -- Aumenta el contador
						Else     -- Si ya se enviaron todos los datos por SPI
							SCS2 <= '1';  -- Deshabilita el SPI CHIP-SELECT (activo bajo)
							clkEn <= '0'; -- Deshabilita el reloj de salida SPI
							SDATA <= '0'; -- Inicializa la senial que contiene los datos
							dCount <= 0;  -- Inicializa el contador del registro de corrimiento
							DONE   <= '1'; -- Ha finalizado la operacion de serializacion
							currentState <= RESYNC; -- Vuelve al estado inicial, esperando datos para serializar
						End If;
						
					When others =>
						DONE <= '0';
						currentState <= DATA_FETCH;
				End case;
			End If;
		End If;
	end process;

	SCLK <= SPIClk when (EDGE = '0' and clkEN = '1' and RST = '0') else    -- Reloj SPI. Solo funciona mientras se envian los datos.
			  not SPICLK when (EDGE = '1' and clkEN = '1' and RST = '0') else -- Asimismo, se define si se envia en flanco de subida o bajada
			  '1';

end Behavioral;
