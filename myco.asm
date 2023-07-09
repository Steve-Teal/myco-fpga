;                                         1 of 12 pages
;------------------------------------------------------------------------------------;
;                                                                                    ;
; myco-fpga implementation Steve Teal – here with text added by Juergen Pintaske v4  ;
; An emulator for the MyCo/TPS 4-bit computer system designed by Burkhard Kainka     ;
;                                                                                    ;
;------------------------------------------------------------------------------------;

;  The different Registers in this TPS / MyCo
;     | INPUT | RA | RB | RC | RD | PAGE | PC | ALU | DELAY | SKIP | SUB | PWM | OUT |
; size: 4 bit   4    4    4    4    4      4    4     4       4      8     4     4    

;  And the 3 Push Buttons for Programming and Controlling TPS / MyCo
;  | S1(BIT0) | S2(BIT1) | RESET |  the 3 push buttons to program and control TPS/MyCo
;

; Start of Program
                BR START  ;  Branch to Start of program  (t1 to  point1–there is f1) 

;
;  Register definitions 
;

REGA            DW 0      ; A,B,C and D are the internal Myco registers
REGB            DW 0      ; B
REGC            DW 0      ; C
REGD            DW 0      ; D

PC              DW 0      ; Program Counter
PAGE            DW 0      ; PAGE Register, contains the top 4 bits 
                          ;                for absolute jump instructions

CALLFROM        DW 0      ; Address where the subroutine was called from to return to

DATA            DW 0      ; DATA (low nibble  ) part of current Myco instruction 
INSTRUCTION     DW 0      ;      (high nibble )

R0              DW 0      ; General purpose registers used by the emulator
R1              DW 0      ;
PREVSWITCH      DW 0      ;  


;
; IO Addresses for various peripherals 
;

SWITCH          DW 0  ; Switch inputs, bit 0 is switch 1, bit 1 switch 2, 
                      ;     0 when pressed, 1 when not pressed

DOUT            DW 1  ; Output port  LEDS (bits 0 - 3) 

DIN             DW 2  ; Input port (bits 0 - 3)

TIMER           DW 3  ; Timer port, the CPU will pause for the number of milli-seconds
                      ;    written to this port
PWM             DW 4  ; PWM control register 0 = full off, 15 = full on, 
                      ;    frequency ~16KHz

;
; Start of program code
;

START           LOAD #0                 ; Clear MyCo registers   (f1)
                STORE REGA              ;    Register A
                STORE REGB              ;    Register B
                STORE REGC              ;    Register C
                STORE REGD              ;    Register D
                STORE PAGE              ;      PAGE Register
                STORE CALLFROM          ;      Subroutine Call Register

                OUT PWM                 ;    Set PWM and DOUT to 0
                OUT DOUT                ;    And OUTPUT Register

                IN SWITCH               ; Read switches (push buttons SW1 and SW2)
                STORE PREVSWITCH        ;    and save into Previous Switch 

                AND #2                  ; Mask SW2
                BNZ RUN                 ; Branch to RUN if SW2 is not pressed     (t2)

PROGRAMLOOP     STORE PC                ; Programming mode, falling into this, A will 
                                        ;    equal 0 and clear PC
                OUT DOUT                ; Display lower nibble of PC on LEDS...
                LOAD #300               ; ...for 300mS
                OUT TIMER
                CALL FETCH              ; Read instruction (and data)
                CALL PROGRAMINST        ; Display/Change instruction
                CALL PROGRAMDATA        ; Display/Chnage data
                LOAD PC                 ; Increment PC 
                ADD #1
                BR PROGRAMLOOP          ; Loop – stay in this Program Loop

;                                         
RUN             LOAD #0                 ; RUN mode, clear program counter        (f2)
RUNLOOP         STORE PC
                CALL FETCH              ; Read instruction (and data)            (t3)
                LOAD @INSTTABLE         ; Get address of instruction jump table
                ADD INSTRUCTION         ; Add the 4-bit instruction to it
                OR #0xB000              ; Turn it into a 'BR' branch instruction
                STORE BRINST            ; and store it
BRINST          NOP                     ; Replaced with BR into instruction table


; Instruction jump table 

INSTTABLE       BR INCPC       ; NOP          ; 0   No Operation, just increment PC
                BR TOPORT      ; To Port      ; 1   Transfer low 4 bits to OUTPUT Port
                BR WAIT        ; Wait         ; 2   DELAY 1ms to 60 sec
                BR JUMPBACK    ; Jump Back    ; 3   JUMP BACK 0 to 15 addresses
                BR SETA        ; A<=          ; 4   LOAD Register A with n
                BR ATO         ; <=A          ; 5   STORE A to other places
                BR TOA         ; A<=          ; 6   LOAD  A from different places
                BR CALC        ; <=A          ; 7   CALCULATE and LOGIC
                BR SETPAGE     ; Set Page     ; 8   SET PAGE REGISTER
                BR JUMPPAGE    ; Jump Page    ; 9   JUMP to 8 bit address
                BR CLOOP       ; C*           ; A   DECREMENT C and JUMP if 0, or PC+1
                BR DLOOP       ; D*           ; B   DECREMENT D and JUMP if 0, or PC+1
                BR SKIPIF      ; Skip If      ; C   SKIP over next addr., if cond. met
                BR CALLSUB     ; Call         ; D   CALL SUBROUTINE
                BR SUBRETURN   ; Ret          ; E   RETURN from Subroutine
                BR INCPC       ; NOP          ; F   No Operation, just increment PC

; Display/Change instruction

PROGRAMINST     LOAD INSTRUCTION      ; Get instruction nibble
                OUT DOUT              ; Display on LEDS
                CALL WAITSWITCH       ; Wait for switch press                   (   )
                BNZ PINST2            ; Return if SW2 is pressed                (   )
                                      ; (leaving instruction unchanged)
                LOAD #0               ; SW1 pressed new instruction entry start at 0

PINST1          STORE INSTRUCTION
                OUT DOUT              ; Display new instruction on LEDS
                CALL STOREPROGRAM     ; Store new instruction in RAM            (   )
                CALL WAITSWITCH       ; Wait for switch press                   (   )
                BNZ PINST2            ; Return if SW2 is pressed (done editing) (   )
                LOAD INSTRUCTION      ; SW1 pressed, increment new instruction
                ADD #1
                BR PINST1             ; Continue editing, loop                  (   )
PINST2          RETURN



; Display/Change data

PROGRAMDATA     LOAD DATA               ; Get instruction data nibble
                OUT DOUT                ; Display on LEDS
                CALL WAITSWITCH         ; Wait for switch press                 (   )
                BNZ PDATA2              ; Return if SW2 is pressed              (   )
                                        ;    (leaving data unchanged)
                LOAD #0                 ; SW1 pressed new data start at 0
PDATA1          STORE DATA
                OUT DOUT                ; Display new data on LEDS
                CALL STOREPROGRAM       ; Store new data in RAM                 (   )
                CALL WAITSWITCH         ; Wait fro switch press                 (   )
                BNZ PDATA2            ; Return if SW2 is pressed (done editing) (   )
                LOAD DATA               ; SW1 pressed, increment new data
                ADD #1
                BR PDATA1               ; Continue editing, loop                (   )
PDATA2          RETURN

; Store Instruction/Data to RAM
; The RAM is 16 bits wide, each location stores two MyCo instruction bytes
; Bit 0 of the program counter is used to decide 

STOREPROGRAM    LOAD INSTRUCTION      ; Load 'new' instruction
                STORE R1 
;
                CALL R1MUL16          ; Shift instruction to upper nibble       (   )
                OR DATA               ; Store data part of instruction in lower nibble
                STORE R0          ; Store new instruction and data in lower byte of R0
                CALL R0SWAPPCEVEN       ; Byte swap R0 if PC is even            (   )
                LOAD R0
                STORE R1
                CALL READPC             ; Read program memory word              (   )
                                        ;    (two instructions) and store in R0
                ROR PC                  ; Carry flag = bit 0 of PC
                LOAD #0x00FF
                BNC SPGM1               ;                                       (   )
                LOAD #0xFF00
SPGM1           AND R0                  ; Mask high/low instruction byte 
                                        ;     depending on state of carry
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

READPC          ROR PC                  ; Divide PC by two to get word address   ( f4)
                AND #0x3F               ; Mask off other bits                        
                ADD @PROGRAM            ; Add offset to start of program memory      
                STORE RDPC1             ; Store 'LOAD' instruction                   
RDPC1           NOP                     ; NOP replaced by LOAD instruction           
                STORE R0
                RETURN 

; Byte SWAP R0 based on state of PC bit 0
; Used to address program memory high/low bytes

R0SWAPPCEVEN    ROR PC                  ;                                        ( f5)
                BNC SWPC2               ;                                        (   )
SWPC1           RETURN                  ;  
SWPC2           SWAP R0                 ;  
                STORE R0                ;  
                RETURN                  ;  


; Loop until a switch (SW1 or SW2) is pressed
; On return A=0 if SW1 is pressed or A=1 if SW2 is pressed

WAITSWITCH      CALL READSWITCHES       ;                                        (   )
                SUB #1                  ;  
                BNC WAITSWITCH          ;                                        (   )
                RETURN                  ;  


; Multiply R1 by 16
R1MUL16         CALL R1MUL2             ;                                        (   )
                CALL R1MUL2             ;                                        (   )
                CALL R1MUL2             ;                                        (   )
R1MUL2          LOAD R1                 ;  
                ADD R1                  ;  
                STORE R1                ;  
                RETURN                  ;  


; Divide R0 by 16                       ;  

R0DIV16         CALL R0DIV2             ;                                    (f6) (t7)
                CALL R0DIV2             ;                                         (t7)
                CALL R0DIV2             ;                                         (t7)
R0DIV2          ROR R0                  ;  
                STORE R0                ;  
                RETURN                  ;  
                

;                                          
; Read, debounce and edge detect switches (SW1 and SW2)
; On return A.0 = 1 when SW1 pressed since last call
;           A.1 = 1 when SW2 pressed since last call

READSWITCHES    IN SWITCH               ; Read switch inputs                     (   )
                XOR PREVSWITCH          ; XOR to see if switche state has changed 
                                        ;     since previous call
                BNZ RSW2                ; Branch if switches have changed        (   )
RSW1            LOAD #0
                RETURN
RSW2            STORE R0                ; Store differance between new 
                                        ;      and old switch state
                LOAD #30                ; Wait 30mS (debounce time)
                OUT TIMER
                IN SWITCH               ; Read switches again
                XOR PREVSWITCH          ; Check for match with first read
                XOR R0
                BNZ RSW1                ; Branch if switch state is different    (   )
                                        ;      from first read
                LOAD R0                 ; XOR'ing differance between old state 
                                        ;      and new state...
                XOR PREVSWITCH          ; and old state will result in the new state
                STORE PREVSWITCH        ; Update PREVSWITCH with new switch state
                XOR #3                  ; A = new switch state, complement because 
                                        ;    inputs are low when switch is pressed
                AND R0                  ; Mask bits that have not changed
                RETURN

; Fetch instruction from program memory using PC and split into 
; INSTRUCTION and DATA nibbles

FETCH           CALL READPC             ;                            ( f3)  ( t4)
                CALL R0SWAPPCEVEN       ;                                   ( t5)
                LOAD R0                 ; R0 is instruction byte
                AND #0xF                ; Mask and store DATA nibble
                STORE DATA              ; 
                CALL R0DIV16            ; Shift instruction byte 4 bits right ( t6)
                LOAD R0                 ;  
                AND #0xF                ; Mask and store INSTRUCTION nibble
                STORE INSTRUCTION
                RETURN

; Add one to the program counter and branch to the main run loop    NOP             0n

INCPC           LOAD PC                 ;                                    (   )
                ADD #1                  ;  
                BR RUNLOOP              ;                                    (   )

; Execute the 'to port' instruction, write the contents of the DATA nibble to DOUT  1n

TOPORT          LOAD DATA               ;                                    (   )
                OUT DOUT                ;  
                BR INCPC                ;                                    (   )

; Execute the 'wait' instruction, lookup the timer value in a table                 2n
; indexed by the DATA nibble and write to the timer

WAIT            LOAD @WAITTABLE         ; Add DATA value to the timer table offset
                ADD DATA
                STORE READWAITTIME      ; Store 'LOAD' instruction
READWAITTIME    NOP                     ; NOP replaced with LOAD instruction
                OUT TIMER               ; Write to timer, stops CPU for number of 
                                        ;     milli-seconds written
                BR INCPC                ;                                      (   )

; Lookup table used by the wait instruction

WAITTABLE       DW 1       ; 1mS        ;                                           20
                DW 2       ; 2mS        ;                                           21
                DW 5       ; 5mS        ;                                           22
                DW 10      ; 10mS       ;                                           23
                DW 20      ; 20mS       ;                                           24
                DW 50      ; 50mS       ;                                           25
                DW 100     ; 100mS      ;                                           26
                DW 200     ; 200mS      ;                                           27
                DW 500     ; 500mS      ;                                           28
                DW 1000    ; 1S         ;                                           29
                DW 2000    ; 2S         ;                                           2A
                DW 5000    ; 5S         ;                                           2B
                DW 10000   ; 10S        ;                                           2C
                DW 20000   ; 20S        ;                                           2D
                DW 30000   ; 30S        ;                                           2E
                DW 60000   ; 60S        ;                                           2F


; Execute the 'jump back' instruction - subtract the DATA value                     3n
; from the program counter

JUMPBACK        LOAD PC                 ;  
                SUB DATA                ;  
                BR RUNLOOP              ;                                      (   )
  
; Execute the 'seta' instruction                                                    4n

SETA            LOAD DATA               ;  
                STORE REGA              ;  
                BR INCPC                ;                                      (   )

; Execute the '...<=A' instructions the DATA nibble indexes a branch table          5n

ATO             LOAD @ATOTABLE          ; Offset to branch table
                ADD DATA                ; add DATA
                OR #0xB000              ; convert to BR instruction
                STORE BRATO             ; Store instruction
                LOAD REGA               ; LOAD A with REGA - this is common to all
                                        ;     'set to A' instructions
BRATO           NOP

ATOTABLE        BR INCPC       ;  NOP  - not used                                   50
                BR ATOB        ;  COPY register A to Register B                     51
                BR ATOC        ;  COPY register A to Register C                     52
                BR ATOD        ;  COPY register A to Register D                     53
                BR ATODOUT     ;  COPY register A to Dout                           54
                BR ATODOUT0    ;  COPY register A to Dout.0                         55
                BR ATODOUT1    ;  COPY register A to Dout.1                         56
                BR ATODOUT2    ;  COPY register A to Dout.2                         57
                BR ATODOUT3    ;  COPY register A to Dout.3                         58
                BR ATOPWM      ;  COPY register A to PWM OUT                        59
                BR INCPC       ;  NOP  - not used                                   5A
                BR INCPC       ;  NOP  - not used                                   5B
                BR INCPC       ;  NOP  - not used                                   5C
                BR INCPC       ;  NOP  - not used                                   5D
                BR INCPC       ;  NOP  - not used                                   5E
                BR INCPC      ;   NOP  - not used                                   5F

; Execute B<=A instruction                                                          51

ATOB            STORE REGB    ; 
                BR INCPC      ;                                              (   )

; Execute C<=A instruction                                                          52

ATOC            STORE REGC    ; 
                BR INCPC      ;                                              (   )

; Execute D<=A instruction                                                          53

ATOD            STORE REGD    ; 
                BR INCPC      ;                                              (   )

;
; Execute DOUT<=A instruction                                                       54
;

ATODOUT         OUT DOUT               ;  
                BR INCPC               ;                                    (   )

ATODOUT0        LOAD #1                 ; DOUT0 <= A.0
                BR ATX1                 ;                                   (   )
ATODOUT1        LOAD #2                 ; DOUT1 <= A.0
                BR ATX1                 ;                                   (   )
ATODOUT2        LOAD #4                 ; DOUT2 <= A.0
                BR ATX1                 ;                                   (   )
ATODOUT3        LOAD #8                 ; DOUT3 <= A.0
ATX1            STORE R0                ;                                           55
                ROR REGA                ; Copy A.0 to carry flag
                BNC ATX2                ; branch if A.0 = 0                 (   )
                IN DOUT                 ; Set selected bit in DOUT
                OR R0
                BR ATODOUT              ;                                   (   )
ATX2            LOAD R0                 ; Clear selected bit in DOUT...
                XOR #0xF                ; Complement bit selection
                STORE R0
                IN DOUT                 ; Read current DOUT
                AND R0                  ; Mask bit to be cleared
                BR ATODOUT              ; Write new value to DOUT           (   )

; Execute PWM<=A                                                                    59

ATOPWM          OUT PWM                 ; 
                BR INCPC                ;                                   (   )

; Execute the 'A<=...' instructions the DATA nibble indexes a branch table          6n

TOA             LOAD @TOATABLE       ; Offset to branch table
                ADD DATA             ; add DATA nibble   
                OR #0xB000           ; Convert to BR instruction
                STORE BRTOA          ; Store instruction
                IN DIN               ; Read DIN some instructions require DIN reading
BRTOA           NOP                     ; Replaced by BR instruction



TOATABLE        BR INCPC      ;  NOP  - not used                                    60
                BR BTOA       ;  Register B to Register A                           61
                BR CTOA       ;  Register C to Register A                           62
                BR DTOA       ;  Register D to Register A                           63
                BR DINTOA     ;  INPUT      to Register A                           64
                BR DIN0TOA    ;  INPUT.0    to Register A                           65
                BR DIN1TOA    ;  INPUT.1    to Register A                           66
                BR DIN2TOA    ;  INPUT.2    to Register A                           67
                BR DIN3TOA    ;  INPUT.3    to Register A                           68
                BR AD1TOA     ;  AD1        to Register A                           69
                BR AD2TOA     ;  AD2        to Register A                           6A
                BR INCPC      ;  NOP  - not used                                    6B
                BR INCPC      ;  NOP  - not used                                    6C
                BR INCPC      ;  NOP  - not used                                    6D
                BR INCPC      ;  NOP  - not used                                    6E
                BR INCPC      ;  NOP  - not used                                    6F


; Execute A<=B                                                                      61

BTOA            LOAD REGB     ; 
TXA1            STORE REGA    ; 
                BR INCPC      ;                                              (   )

; Execute A<=C                ;                                                     62

CTOA            LOAD REGC     ; 
                BR TXA1       ;                                              (   )


;
; Execute A<=D                                                                      63

DTOA            LOAD REGD     ; 
                BR TXA1       ;                                              (   )

; Execute A<=DIN                                                                    64

DINTOA          IN DIN        ; 
                BR TXA1       ;                                              (   )

DIN0TOA         AND #1                  ; A<=DIN.0                                  65
                BR TXA2                 ;                                    (   )

DIN1TOA         AND #2                  ; A<=DIN.1                                  66
                BR TXA2                 ;                                    (   )

DIN2TOA         AND #4                  ; A<=DIN.2                                  67
                BR TXA2                 ;                                    (   )

DIN3TOA         AND #8                  ; A<=DIN.3                                  68
TXA2            BNZ TXA3                ;                                    (   )
                BR TXA1                 ;                                    (   )
TXA3            LOAD #1
                BR TXA1                 ;                                    (   )

; ADC not implemented - set REGA to 0 when A<=AD1 or A<=AD2 is executed             69
;                                                                                   6A
AD1TOA
AD2TOA          LOAD #0       ; 
                BR TXA1       ;                                              (   )

; Calculation instructions - branch table                                          7n

CALC            LOAD @CALCTABLE   ; 
                ADD DATA          ; 
                OR #0xB000        ; 
                STORE BRCALC      ; 
                LOAD REGA         ; 
BRCALC          NOP               ; 

CALCTABLE       BR INCPC     ; NOP, not used                                       70
                BR ADD1      ; A <= A + 1                                          71
                BR SUB1      ; A <= A – 1                                          72
                BR ADDB      ; A <= A + B                                          73
                BR SUBB      ; A <= A – B                                          74
                BR MULB      ; A <= A * B                                          75
                BR DIVB      ; A <= A / B                                          76
                BR ANDB      ; A <= A AND B                                        77
                BR ORB       ; A <= A OR  B                                        78
                BR XORB      ; A <= A XOR B                                        79
                BR NOTA      ; A = NOT A                                           7A
                BR INCPC     ; NOP,  not used                                      7B
                BR INCPC     ; NOP,  not used                                      7C
                BR INCPC     ; NOP,  not used                                      7D
                BR INCPC     ; NOP,  not used                                      7E
                BR INCPC     ; NOP,  not used                                      7F

; A<=A+1                                                                           71
              
ADD1            ADD #1       ; 
CALCX           STORE REGA   ; 
                BR INCPC     ;                                               (   )

; A<=A-1                                                                           72

SUB1            SUB #1       ; 
                BR CALCX     ;                                               (   )

; A<=A+B                                                                           73

ADDB            ADD REGB     ; 
                BR CALCX     ;                                               (   )

; A<=A-B                                                                           74

;
SUBB            SUB REGB     ; 
                BR CALCX     ;                                               (   )

; A<=A*B                                                                           75

MULB            LOAD REGB    ; 
                STORE R1     ; 
                CALL R1MUL16 ;                                               (   )
                LOAD #4      ; 
MUL1            STORE R0     ; 
                LOAD R1      ; 
                ADD R1       ; 
                STORE R1     ; 
                AND #0x100   ; 
                BNZ MUL2     ;                                               (   )
                BR MUL3      ;                                               (   )
MUL2            LOAD R1      ; 
                ADD REGA     ; 
                STORE R1     ; 
MUL3            LOAD R0      ; 
                SUB #1       ; 
                BNZ MUL1     ;                                               (   )
                LOAD R1      ; 
                AND #0xF     ; 
                BR CALCX     ;                                               (   )

; A<=A/B                                                                          76

DIVB            LOAD REGB    ; 
                STORE R1     ; 
                CALL R1MUL16 ;                                               (   )
                LOAD #4      ; 
DIV1            STORE R0     ; 
                LOAD REGA    ; 
                ADD REGA     ; 
                STORE REGA   ; 
                SUB R1       ; 
                BNC DIV2     ;                                                (   )
                OR #1        ; 
                STORE REGA   ; 
DIV2            LOAD R0      ; 
                SUB #1       ; 
                BNZ DIV1     ;                                                (   )
                LOAD REGA    ; 
                AND #0xF     ; 
                BR CALCX     ;                                                (   )

; A<=A&B                                                                            77

ANDB            AND REGB     ; 
                BR CALCX     ;                                                (   )

; A <=A|B                                                                           78

ORB             OR REGB      ; 
                BR CALCX     ;                                                (   )

; A <=A^B                                                                           79

XORB            XOR REGB     ; 
                BR CALCX     ;                                                (   )

; A <= ~A                                                                           7A

NOTA            XOR #0xF     ; 
                BR CALCX     ;                                                (   )

;
;  Set Page Register   ( and as well shift 4xleft to prepare )                     8n


SETPAGE         LOAD DATA      ; LOAD the data value to be used as PAGE nibble
                STORE R1       ; store for now into R1 support register
                CALL R1MUL16   ; shift left 4x to have it as the high nibble, (   )
                STORE PAGE     ; store into PAGE
                BR INCPC       ; and brach to INCPC                           (   )


;
;  Jump to 8 bit address                                                           9n

JUMPPAGE        LOAD PAGE       ;  Load value in PAGE (had been shifted 4 left – x16)
                OR DATA         ;  OR with data  so it is now high nibble low nibble
                BR RUNLOOP      ;     and branch to RUNLOOP                   (   )


;
;  Decrement Register C    jump to address if 0, else continue with next address   An

CLOOP           LOAD REGC       ;  get Register Value C
                SUB #1          ;  Decrement the register
                BNC INCPC       ;  Branch IF NOT 0 to INCPC, so just continue (   )
                STORE REGC      ;            store value back into the register
                BR JUMPPAGE     ;            and Branch to JUMPPAGE           (   )


;
;  Decrement Register D    jump to address if 0, else continue with next address   Bn

DLOOP           LOAD REGD       ;  get Register Value D
                SUB #1          ;  Decrement the register value
                BNC INCPC       ;  Branch IF NOT 0 to INCPC, so just continue  (   )
                STORE REGD      ;            store value back into the register
                BR JUMPPAGE     ;            and Branch to JUMPPAGE            (   )


;
;  SKIP over next address if condition is met, else continue                       Cn

SKIPIF          LOAD @SKIPTABLE  ;  
                ADD DATA         ;  
                OR #0xB000       ;  
                STORE BRSKIP     ;  
BRSKIP          NOP              ;  

SKIPTABLE       BR INCPC         ;  NOP,  not used                                 C0
                BR AGTB          ;  SKIP IF A > B                                  C1
                BR ALTB          ;  SKIP IF A < B                                  C2
                BR AEQB          ;  SKIP IF A = B                                  C3
                BR DIN01         ;  SKIP IF Din.0 = 1                              C4
                BR DIN11         ;  SKIP IF Din.1 = 1                              C5
                BR DIN21         ;  SKIP IF Din.2 = 1                              C6
                BR DIN31         ;  SKIP IF Din.3 = 1                              C7
                BR DIN00         ;  SKIP IF Din.0 = 0                              C8
                BR DIN10         ;  SKIP IF Din.1 = 0                              C9
                BR DIN20         ;  SKIP IF Din.2 = 0                              CA
                BR DIN30         ;  SKIP IF Din.3 = 0                              CB
                BR S10           ;  SKIP IF S1 = 0 pushed                          CC
                BR S20           ;  SKIP IF S2 = 0 pushed                          CD
                BR S11           ;  SKIP IF S1 = 1 not pushed                      CE
                BR S21           ;  SKIP IF S2 = 1 not pushed                      CF


AGTB            LOAD REGB        ;                                                 C1
                SUB REGA         ;  
                BNC SKIP         ;                                           (   )
                BR INCPC         ;                                           (   )

ALTB            LOAD REGA        ;                                                 C2
                SUB REGB         ;  
                BNC SKIP         ;                                           (   )
                BR INCPC         ;                                           (   )

AEQB            LOAD REGA        ;                                                 C3
                SUB REGB         ;  
                BNZ INCPC        ;                                           (   )
                BR SKIP          ;                                           (   )

DIN01           LOAD #1          ;                                                 C4
                BR DINX1         ;                                           (   )

DIN11           LOAD #2          ;                                                 C5
                BR DINX1         ;                                           (   )

DIN21           LOAD #4          ;                                                 C6
                BR DINX1         ;                                           (   )

DIN31           LOAD #8          ;                                                 C7
DINX1           STORE R1         ;  
                IN DIN           ;  
                AND R1           ;  
                BNZ SKIP         ;                                           (   )
                BR INCPC         ;                                           (   )
            
;
DIN00           LOAD #1          ;                                                 C8
                BR DINX0         ;                                           (   )

DIN10           LOAD #2          ;                                                 C9
                BR DINX0         ;                                           (   )

DIN20           LOAD #4          ;                                                 CA
                BR DINX0         ;                                           (   )

DIN30           LOAD #8          ;                                                 CB

DINX0           STORE R1         ;  
                IN DIN           ;  
                AND R1           ;  
                BNZ INCPC        ;                                           (   )
                BR SKIP          ;                                           (   )

S10             IN SWITCH        ;                                                 CC
                AND #1           ;  
                BNZ INCPC        ;                                           (   )
                BR SKIP          ;                                           (   )

S20             IN SWITCH        ;                                                 CD
                AND #2           ;  
                BNZ INCPC        ;                                           (   )
                BR SKIP          ;                                           (   )

S11             IN SWITCH        ;                                                CE
                AND #1           ;  
                BNZ SKIP         ;                                           (   )
                BR INCPC         ;                                           (   )

S21             IN SWITCH        ;                                                 CF
                AND #2           ;  
                BNZ SKIP         ;                                           (   )
                BR INCPC         ;                                           (   )

SKIP            LOAD PC          ;  
                ADD #2           ;  
                BR RUNLOOP       ;                                           (   )


;
;  CALL SUBROUTINE                                                                 Dn

CALLSUB         LOAD PC          ;  
                STORE CALLFROM   ;  
                BR JUMPPAGE      ;                                           (   )


;
;  RETURN from Subroutine                                                          En

SUBRETURN       LOAD CALLFROM    ;  
                STORE PC         ;  
                BR INCPC         ;                                           (   )

; 
; Not used yet  in this implementation of TPS / MYCO                               Fn
;    So like NOP

;   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++























;
;  Pre-Programmed Code of the original TPS Examples, selected via the 4 Input Bits
;  The start adresses will initiate the following function:
;  And there are subroutines that can be used in new code.
;  INPUT VALUE SET:
;  0000  0   
;  0001  1   
;  0010  2   
;  0011  3   
;  0100  4   
;  0101  5   
;  0110  6   
;  0111  7   4   Bit 3 is low - pushed
;  1000  8   
;  1001  9   
;  1010  A   
;  1011  B   3   Bit 2 is low - pushed
;  1100  C   5   Bit 0 and 1 are low - pushed
;  1101  D   2   Bit 1 is low - pushed
;  1110  E   1   Bit 0 is low - pushed
;  1111  F   
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
