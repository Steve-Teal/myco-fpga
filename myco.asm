;-----------------------------------------------------
;
; myco-fpga 
; An emulator for the MyCo/TPS 4-bit computer system
;
;-----------------------------------------------------

                BR START
;
; Register definitions 
;

REGA            DW 0        ; A,B,C and D are the internal Myco registers
REGB            DW 0
REGC            DW 0
REGD            DW 0
PC              DW 0        ; Program Counter
PAGE            DW 0        ; Page register, contains the top 4-bits for absolute jump instructions
CALLFROM        DW 0        ; Address where subroutine was called from
DATA            DW 0        ; DATA (low nibble) part of current Myco instruction 
INSTRUCTION     DW 0
R0              DW 0        ; General purpose registers used by the emulator
R1              DW 0
PREVSWITCH      DW 0        

;
; IO Addresses for various peripherals 
;

SWITCH          DW 0  ; Switch inputs, bit 0 is switch 1, bit 1 switch 2, 0 when pressed, 1 when not pressed
DOUT            DW 1  ; Output port  LEDS (bits 0 - 3) 
DIN             DW 2  ; Input port (bits 0 - 3)
TIMER           DW 3  ; Timer port, the CPU will pause for the number of milli-seconds written to this port
PWM             DW 4  ; PWM control register 0 = full off, 15 = full on, frequency ~16KHz

;
; Start of program
;

START           LOAD #0                 ; Clear MyCo registers
                STORE REGA
                STORE REGB
                STORE REGC
                STORE REGD
                STORE PAGE
                STORE CALLFROM
                OUT PWM                 ; Set PWM and DOUT to 0
                OUT DOUT
                IN SWITCH               ; Read switches (push buttons SW1 and SW2)
                STORE PREVSWITCH
                AND #2                  ; Mask SW2
                BNZ RUN                 ; Branch to RUN if SW2 is not pressed

PROGRAMLOOP     STORE PC                ; Programming mode, falling into this A will equal 0 and clear PC
                OUT DOUT                ; Display lower nibble of PC on LEDS...
                LOAD #300               ; ...for 300mS
                OUT TIMER
                CALL FETCH              ; Read instruction (and data)
                CALL PROGRAMINST        ; Display/Change instruction
                CALL PROGRAMDATA        ; Display/Chnage data
                LOAD PC                 ; Increment PC 
                ADD #1
                BR PROGRAMLOOP          ; Loop

RUN             LOAD #0                 ; RUN mode, clear program counter
RUNLOOP         STORE PC
                CALL FETCH              ; Read instruction (and data)
                LOAD @INSTTABLE         ; Get address of instruction jump table
                ADD INSTRUCTION         ; Add the 4-bit instruction to it
                OR #0xB000              ; Turn it into a 'BR' branch instruction
                STORE BRINST            ; and store it
BRINST          NOP                     ; Replaced with BR into instruction table

; Instruction jump table 

INSTTABLE       BR INCPC       ; NOP
                BR TOPORT      ; To Port
                BR WAIT        ; Wait
                BR JUMPBACK    ; Jump Back
                BR SETA        ; A<=
                BR ATO         ; <=A
                BR TOA         ; A<=
                BR CALC        ; <=A
                BR SETPAGE     ; Set Page
                BR JUMPPAGE    ; Jump Page
                BR CLOOP       ; C*
                BR DLOOP       ; D*
                BR SKIPIF      ; Skip If
                BR CALLSUB     ; Call
                BR SUBRETURN   ; Ret
                BR INCPC       ; NOP

; Display/Change instruction

PROGRAMINST     LOAD INSTRUCTION        ; Get instruction nibble
                OUT DOUT                ; Display on LEDS
                CALL WAITSWITCH         ; Wait for switch press
                BNZ PINST2              ; Return if SW2 is pressed (leaving instruction unchanged)
                LOAD #0                 ; SW1 pressed new instruction entry start at 0
PINST1          STORE INSTRUCTION
                OUT DOUT                ; Display new instruction on LEDS
                CALL STOREPROGRAM       ; Store new instruction in RAM
                CALL WAITSWITCH         ; Wait for switch press
                BNZ PINST2              ; Return if SW2 is pressed (done editing)
                LOAD INSTRUCTION        ; SW1 pressed, increment new instruction
                ADD #1
                BR PINST1               ; Continue editing, loop
PINST2          RETURN

; Display/Change data

PROGRAMDATA     LOAD DATA               ; Get instruction data nibble
                OUT DOUT                ; Display on LEDS
                CALL WAITSWITCH         ; Wait for switch press
                BNZ PDATA2              ; Return if SW2 is pressed (leaving data unchanged)
                LOAD #0                 ; SW1 pressed new data start at 0
PDATA1          STORE DATA
                OUT DOUT                ; Display new data on LEDS
                CALL STOREPROGRAM       ; Store new data in RAM
                CALL WAITSWITCH         ; Wait fro switch press
                BNZ PDATA2              ; Return if SW2 is pressed (done editing)
                LOAD DATA               ; SW1 pressed, increment new data
                ADD #1
                BR PDATA1               ; Continue editing, loop
PDATA2          RETURN

; Store Instruction/Data to RAM
; The RAM is 16 bits wide, each location stores two MyCo instruction bytes
; Bit 0 of the program counter is used to decide 

STOREPROGRAM    LOAD INSTRUCTION        ; Load 'new' instruction
                STORE R1 
                CALL R1MUL16            ; Shift instruction to upper nibble
                OR DATA                 ; Store data part of instruction in lower nibble
                STORE R0                ; Store new instruction and data in lower byte of R0
                CALL R0SWAPPCEVEN       ; Byte swap R0 if PC is even
                LOAD R0
                STORE R1
                CALL READPC             ; Read program memory word (two instructions) and store in R0
                ROR PC                  ; Carry flag = bit 0 of PC
                LOAD #0x00FF
                BNC SPGM1
                LOAD #0xFF00
SPGM1           AND R0                  ; Mask high/low instruction byte depending on state of carry
                OR R1                   ; Store new instruction
                STORE R0
                ROR PC                  ; Calculate location to store instruction
                AND #0x3F
                ADD @PROGRAM
                OR #0x1000              ; Convert address into STORE instruction
                STORE WRPC1
                LOAD R0
WRPC1           NOP                     ; NOP is replaced with STORE instruction
                RETURN

; Read program memory and store in R0, PC is used to address program memory

READPC          ROR PC                  ; Divide PC by two to get word address              
                AND #0x3F               ; Mask off other bits
                ADD @PROGRAM            ; Add offset to start of program memory
                STORE RDPC1             ; Store 'LOAD' instruction
RDPC1           NOP                     ; NOP replaced by LOAD instruction
                STORE R0
                RETURN
; Byte SWAP R0 based on state of PC bit 0
; Used to address program memory high/low bytes

R0SWAPPCEVEN    ROR PC
                BNC SWPC2
SWPC1           RETURN
SWPC2           SWAP R0
                STORE R0
                RETURN

; Loop until a switch (SW1 or SW2) is pressed
; On return A=0 if SW1 is pressed or A=1 if SW2 is pressed

WAITSWITCH      CALL READSWITCHES
                SUB #1
                BNC WAITSWITCH
                RETURN
; Multiply R1 by 16

R1MUL16         CALL R1MUL2
                CALL R1MUL2
                CALL R1MUL2
R1MUL2          LOAD R1
                ADD R1
                STORE R1
                RETURN  
; Divide R0 by 16

R0DIV16         CALL R0DIV2
                CALL R0DIV2
                CALL R0DIV2
R0DIV2          ROR R0
                STORE R0
                RETURN
                
; Read, debounce and edge detect switches (SW1 and SW2)
; On return A.0 = 1 when SW1 pressed since last call
;           A.1 = 1 when SW2 pressed since last call

READSWITCHES    IN SWITCH               ; Read switch inputs
                XOR PREVSWITCH          ; XOR to see if switche state has changed since previous call
                BNZ RSW2                ; Branch if switches have changed
RSW1            LOAD #0
                RETURN
RSW2            STORE R0                ; Store differance between new and old switch state
                LOAD #30                ; Wait 30mS (debounce time)
                OUT TIMER
                IN SWITCH               ; Read switches again
                XOR PREVSWITCH          ; Check for match with first read
                XOR R0
                BNZ RSW1                ; Branch if switch state is different from first read
                LOAD R0                 ; XOR'ing differance between old state and new state...
                XOR PREVSWITCH          ; and old state will result in the new state
                STORE PREVSWITCH        ; Update PREVSWITCH with new switch state
                XOR #3                  ; A = new switch state, complement because inputs are low when switch is pressed
                AND R0                  ; Mask bits that have not changed
                RETURN

; Fetch instruction from program memory using PC and split into INSTRUCTION and DATA nibbles

FETCH           CALL READPC
                CALL R0SWAPPCEVEN
                LOAD R0                 ; R0 is instruction byte
                AND #0xF                ; Mask and store DATA nibble
                STORE DATA
                CALL R0DIV16            ; Shift instruction byte 4 bits right
                LOAD R0
                AND #0xF                ; Mask and store INSTRUCTION nibble
                STORE INSTRUCTION
                RETURN

; Add one to the program counter and branch to the main run loop

INCPC           LOAD PC
                ADD #1
                BR RUNLOOP

; Execute the 'to port' instruction, write the contents of the DATA nibble to DOUT

TOPORT          LOAD DATA
                OUT DOUT
                BR INCPC

; Execute the 'wait' instruction, lookup the timer value in a table indexed by the DATA nibble and write to the timer

WAIT            LOAD @WAITTABLE         ; Add DATA value to the timer table offset
                ADD DATA
                STORE READWAITTIME      ; Store 'LOAD' instruction
READWAITTIME    NOP                     ; NOP replaced with LOAD instruction
                OUT TIMER               ; Write to timer, stops CPU for number of milli-seconds written
                BR INCPC

; Lookup table used by the wait instruction

WAITTABLE       DW 1       ; 1mS
                DW 2       ; 2mS
                DW 5       ; 5mS
                DW 10      ; 10mS
                DW 20      ; 20mS
                DW 50      ; 50mS
                DW 100     ; 100mS
                DW 200     ; 200mS
                DW 500     ; 500mS
                DW 1000    ; 1S
                DW 2000    ; 2S
                DW 5000    ; 5S
                DW 10000   ; 10S
                DW 20000   ; 20S
                DW 30000   ; 30S
                DW 60000   ; 60S

; Execute the 'jump back' instruction - subtract the DATA value from the program counter

JUMPBACK        LOAD PC
                SUB DATA
                BR RUNLOOP

; Execute the 'seta' instruction 

SETA            LOAD DATA
                STORE REGA
                BR INCPC

; Execute the '...<=A' instructions the DATA nibble indexes a branch table

ATO             LOAD @ATOTABLE          ; Offset to branch table
                ADD DATA                ; add DATA
                OR #0xB000              ; convert to BR instruction
                STORE BRATO             ; Store instruction
                LOAD REGA               ; LOAD A with REGA - this is common to all 'set to A' instructions
BRATO           NOP

ATOTABLE        BR INCPC
                BR ATOB
                BR ATOC
                BR ATOD
                BR ATODOUT
                BR ATODOUT0
                BR ATODOUT1
                BR ATODOUT2
                BR ATODOUT3
                BR ATOPWM
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC

; Execute B<=A instruction

ATOB            STORE REGB
                BR INCPC

; Execute C<=A instruction

ATOC            STORE REGC
                BR INCPC

; Execute D<=A instruction

ATOD            STORE REGD
                BR INCPC

; Execute DOUT<=A instruction

ATODOUT         OUT DOUT
                BR INCPC  

ATODOUT0        LOAD #1                 ; DOUT0 <= A.0
                BR ATX1
ATODOUT1        LOAD #2                 ; DOUT1 <= A.0
                BR ATX1
ATODOUT2        LOAD #4                 ; DOUT2 <= A.0
                BR ATX1
ATODOUT3        LOAD #8                 ; DOUT3 <= A.0
ATX1            STORE R0
                ROR REGA                ; Copy A.0 to carry flag
                BNC ATX2                ; branch if A.0 = 0
                IN DOUT                 ; Set selected bit in DOUT
                OR R0
                BR ATODOUT
ATX2            LOAD R0                 ; Clear selected bit in DOUT...
                XOR #0xF                ; Complement bit selection
                STORE R0
                IN DOUT                 ; Read current DOUT
                AND R0                  ; Mask bit to be cleared
                BR ATODOUT              ; Write new value to DOUT

; Execute PWM<=A

ATOPWM          OUT PWM
                BR INCPC

; Execute the 'A<=...' instructions the DATA nibble indexes a branch table

TOA             LOAD @TOATABLE          ; Offset to branch table
                ADD DATA                ; add DATA nibble   
                OR #0xB000              ; Convert to BR instruction
                STORE BRTOA             ; Store instruction
                IN DIN                  ; Read DIN some instructions require DIN reading
BRTOA           NOP                     ; Replaced by BR instruction

TOATABLE        BR INCPC
                BR BTOA
                BR CTOA
                BR DTOA
                BR DINTOA
                BR DIN0TOA
                BR DIN1TOA
                BR DIN2TOA
                BR DIN3TOA  
                BR AD1TOA
                BR AD2TOA
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC   

; Execute A<=B

BTOA            LOAD REGB
TXA1            STORE REGA
                BR INCPC

; Execute A<=C

CTOA            LOAD REGC
                BR TXA1

; Execute A<=D

DTOA            LOAD REGD
                BR TXA1
; Execute A<=DIN

DINTOA          IN DIN
                BR TXA1

DIN0TOA         AND #1                  ; A<=DIN.0
                BR TXA2
DIN1TOA         AND #2                  ; A<=DIN.1
                BR TXA2
DIN2TOA         AND #4                  ; A<=DIN.2
                BR TXA2
DIN3TOA         AND #8                  ; A<=DIN.3
TXA2            BNZ TXA3
                BR TXA1
TXA3            LOAD #1
                BR TXA1

; ADC not implemented - set REGA to 0 when A<=AD1 or A<=AD2 is executed

AD1TOA
AD2TOA          LOAD #0
                BR TXA1

; Calculation instructions - branch table

CALC            LOAD @CALCTABLE
                ADD DATA
                OR #0xB000
                STORE BRCALC
                LOAD REGA
BRCALC          NOP

CALCTABLE       BR INCPC
                BR ADD1
                BR SUB1
                BR ADDB
                BR SUBB
                BR MULB
                BR DIVB
                BR ANDB
                BR ORB
                BR XORB
                BR NOTA
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC
                BR INCPC

; A<=A+1
              
ADD1            ADD #1
CALCX           STORE REGA
                BR INCPC

; A<=A-1

SUB1            SUB #1
                BR CALCX

; A<=A+B

ADDB            ADD REGB
                BR CALCX

; A<=A-B

SUBB            SUB REGB
                BR CALCX
; A<=A*B

MULB            LOAD REGB
                STORE R1
                CALL R1MUL16
                LOAD #4
MUL1            STORE R0
                LOAD R1
                ADD R1
                STORE R1
                AND #0x100
                BNZ MUL2
                BR MUL3
MUL2            LOAD R1
                ADD REGA
                STORE R1
MUL3            LOAD R0
                SUB #1
                BNZ MUL1
                LOAD R1
                AND #0xF
                BR CALCX

; A<=A/B

DIVB            LOAD REGB
                STORE R1
                CALL R1MUL16
                LOAD #4
DIV1            STORE R0
                LOAD REGA
                ADD REGA
                STORE REGA
                SUB R1
                BNC DIV2
                OR #1
                STORE REGA
DIV2            LOAD R0
                SUB #1
                BNZ DIV1
                LOAD REGA
                AND #0xF
                BR CALCX

; A<=A&B

ANDB            AND REGB
                BR CALCX

; A <=A|B

ORB             OR REGB
                BR CALCX

; A <=A^B

XORB            XOR REGB
                BR CALCX

; A <= ~A

NOTA            XOR #0xF
                BR CALCX

SETPAGE         LOAD DATA
                STORE R1
                CALL R1MUL16
                STORE PAGE
                BR INCPC

JUMPPAGE        LOAD PAGE
                OR DATA
                BR RUNLOOP

CLOOP           LOAD REGC
                SUB #1
                BNC INCPC
                STORE REGC
                BR JUMPPAGE

DLOOP           LOAD REGD
                SUB #1
                BNC INCPC
                STORE REGD
                BR JUMPPAGE

SKIPIF          LOAD @SKIPTABLE
                ADD DATA
                OR #0xB000
                STORE BRSKIP
BRSKIP          NOP

SKIPTABLE       BR INCPC
                BR AGTB
                BR ALTB
                BR AEQB
                BR DIN01
                BR DIN11
                BR DIN21
                BR DIN31
                BR DIN00
                BR DIN10
                BR DIN20
                BR DIN30
                BR S10
                BR S20
                BR S11
                BR S21

AGTB            LOAD REGB
                SUB REGA
                BNC SKIP
                BR INCPC

ALTB            LOAD REGA
                SUB REGB
                BNC SKIP
                BR INCPC

AEQB            LOAD REGA
                SUB REGB
                BNZ INCPC
                BR SKIP

DIN01           LOAD #1
                BR DINX1
DIN11           LOAD #2
                BR DINX1
DIN21           LOAD #4
                BR DINX1
DIN31           LOAD #8
DINX1           STORE R1
                IN DIN
                AND R1
                BNZ SKIP
                BR INCPC
            
DIN00           LOAD #1
                BR DINX0
DIN10           LOAD #2
                BR DINX0
DIN20           LOAD #4
                BR DINX0
DIN30           LOAD #8
DINX0           STORE R1
                IN DIN
                AND R1
                BNZ INCPC
                BR SKIP

S10             IN SWITCH
                AND #1
                BNZ INCPC
                BR SKIP

S20             IN SWITCH
                AND #2
                BNZ INCPC
                BR SKIP

S11             IN SWITCH
                AND #1
                BNZ SKIP
                BR INCPC

S21             IN SWITCH
                AND #2
                BNZ SKIP
                BR INCPC

SKIP            LOAD PC
                ADD #2
                BR RUNLOOP

CALLSUB         LOAD PC
                STORE CALLFROM
                BR JUMPPAGE

SUBRETURN       LOAD CALLFROM
                STORE PC
                BR INCPC

PROGRAM         DB 0x64,0x51,0x4E,0x80,0xC3,0x98,0x82,0x95
                DB 0x4D,0x80,0xC3,0x9E,0x82,0x9A,0x4B,0x81
                DB 0xC3,0x94,0x83,0x90,0x47,0x81,0xC3,0x9A
                DB 0x83,0x94,0x43,0x82,0xC3,0x90,0x84,0x90
                DB 0x11,0x28,0x18,0x28,0x34,0x71,0x54,0x59
                DB 0x26,0x34,0x69,0x54,0x59,0x26,0x34,0xFF
                DB 0x54,0xCE,0x71,0x33,0x22,0xCC,0x32,0x40
                DB 0x22,0x71,0x54,0xCE,0x34,0x39,0xFF,0xFF
                DB 0x86,0xD0,0x40,0x71,0x54,0x23,0xCD,0x34
                DB 0xD8,0x40,0x54,0x3B,0xFF,0xFF,0xFF,0xFF
                DB 0x4F,0x93,0x45,0x53,0x19,0x11,0x21,0x19
                DB 0x11,0x21,0x19,0x11,0x20,0xB4,0x10,0xE0
                DB 0x23,0xCE,0x32,0x23,0xCC,0x31,0xE0,0xFF
                DB 0x23,0xCF,0x32,0x23,0xCD,0x31,0xE0,0xFF
                DB 0xCC,0x31,0x40,0x54,0x23,0xCE,0x32,0xCF
                DB 0xE0,0xCC,0x33,0x71,0x23,0xCC,0x31,0x3C

; End of file               
