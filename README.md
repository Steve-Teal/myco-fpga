# myco-fpga
A 4-bit computer system for FPGAs
myco-fpga is a FPGA implementation of the MyCo (My little Computer) system, also known in German as TPS (Tastenprogrammierbare Steuerung).

With this system you can enter, run and edit programs with just three pushbuttons and 4 LEDs. To get you started, several demo programs are pre-loaded. These can easily be modified or overwritten by your own programs.

![System block diagram](pictures/myco1.jpg)

## Installation

All the VHDL files to build myco-fpga included. The exact build process will vary from FPGA to FPGA. You will also need connect external hardware to your FPGA. A minimum system will require 3 push buttons and 4 LEDS. To get the most out of the system a 4-way DIP switch can be used and connected to the 4 in

![System block diagram](pictures/myco2.png)


### Useful links


### ToDo

* ADC - 2 channel external ADC
* Program storage - 

### MIT License

Copyright (c) 2020 Steve Teal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


