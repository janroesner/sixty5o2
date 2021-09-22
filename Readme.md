![Sixty 5o2 Logo](/img/Sixty5o2_Logo.png)

# Introduction

**Sixty/5o2** is a minimal bootloader / micro kernel / mini operating system (if you like) for [Ben Eaters 6502 Computer](https://eater.net/6502) on a breadboard. It is only **1.5kB** in size (assembled) but comes with quite a nice list of features:

1. __Load__ externally assembled __programs__ into RAM via serial connection to Arduino
2. __Run__ programs that were previously loaded into RAM
3. __Load & Run__ programs in one go
4. __Debug__ the full address space via an integrated __hex monitor__ (currently read only)
5. __Clean RAM__ for use with non-volatile RAM or during development
6. __Drive__ the __LCD__ display even at a clock rate of __1MHz__ flawlessly
7. __Drive__ the __mini keyboard__ for input
8. __Video RAM__ based __output routines__ for convenient text display single page / multipage w/ offset
9. Interrupt based loading routine to fetch data via the Arduino's serial connection
10. __Serial Sender__ (node.js) allowes to upload programs to the 6502 (error mitigation included) 
11. __Fully documented source code__

![Breadboard Image](/img/6502b.jpg)

# Motivation

Ben Eaters 6502 breadboard computer is a very special kind of animal and brought lots of fun and joy into my last weeks. A 45 years old processor design that is still able to get things done was fascinating enough for me, to give this project a go - especially, since my first machine was a **Commodore C64** which I programmed in Basic at the end of the 80'ies and never had the chance to get in touch with 6502 assembly.

On my journey during the last weeks I soon surpassed the current state of development (thanks to Ben's schematics) and was able to write a few programs which I ended up burning onto the ROM using the programmer. Soon enough this became painful, because every codechange required to extract the ROM chip from the breadboard, put it into the programmer, burn it, put it back onto the board. This became time consuming and constraining pretty quickly, especially when I attempted to write slightly more complex programs.

So early on I tested, whether I could use the Arduino, connect 8 of it's digital output pins to the VIA 6522 and transfer key strokes on my Mac serially and render them onto the LCD display. As soon as this worked, the path was clear:

**I needed a bootloader that could leverage this power to load externally assembled object code / programs into the RAM and run it from there.**

Luckily I was able to speed up the 6502's clock by just replacing the capacitor of the unstable 555 timer circuit by a smaller one such, that loading data serially was - lets say - at least stable enough. That paved the way to more complex subroutines which now make up my "Sixty/5o2" micro bootloader / micro kernel. It works very well with full clock speed of 1MHz and is hopefully helpful to other 6502 enthusiasts as well.

Especially the serial data transfer is enormously stable, since error mitigation (not correction) is baked into a minimalistic protocol, where there the sender side is implemented in node.js. Unfortunately I was not able to get a stable serial connection with serial terminals like `screen`, `minicom` or `picocom`. Hence I decided to build something myself. On the positive side of things I had the opportunity to integrate content transform using base64 encoding as well as simple error mitigation via a checksum algorithm plus a "send packet again" function.

**It's not perfect, in places not even nice. Last time I personally touched assembler was 20+ years ago, so please be gentle with criticism. PR's are king.**

If you want to get a glimpse, check out the demo video on Youtube:

[![Sixty5o2 - Mini OS for Ben Eater's 6502 Breadboard Computer](/img/Sixty5o2_MiniOS_th.jpg)](https://www.youtube.com/watch?v=sZl2wUgASyk)


# Hardware Requirements

There are only two requirements, both of them can be mitigated though:

1. Use the 1MHz clock (you **MUST** disconnect the clock module, otherwise it interferes)
2. Some people (including me initially) built the mini keyboard such, that the buttons are tied _low_ in normal state, when pushed they get tied _high_. This is opposite to Ben's design in his schematics. I updated my setup according to the schematics, and the default behaviour is now, that the buttons are tied __high__ and only when pushed, they get pulled __low__.

## Possible Mitigation Strategies

1. If you want to run at other clock speeds, you MUST adjust a global constant called `WAIT_C` in the bootloader code. It's a multiplier which is used to _sleep_  and just burns a number of cycles in a routine called `LIB__sleep`. If you run at lower clock speeds, adjust `WAIT_C` to a smaller number until keyboard and main menu become usable.

2. Should your keyboard not be built according to the schematics (so the buttons are normally tied _low_ and when pressed turn _high_), then you need to adjust the routine `VIA__read_keyboard_input`. Simply comment out line 555 in `bootloader.asm`. This will disable the XOR of the read value with 0xf. This way the keystrokes will be interpreted correctly.

# Software Requirements

The following software components are must have's:

- Arduino IDE to be found [here](https://www.arduino.cc/en/main/software)
- Minipro or XG GUI software for Windows for thr TL866 programmer available [here](http://www.autoelectric.cn/en/tl866_main.html)
- The infamous and awesome [VASM Assembler](http://sun.hasenbraten.de/vasm/) to build for the 6502 (Ben's instructions to build and use to be found [here](https://www.youtube.com/watch?v=oO8_2JJV0B4))
- Node.js 8+ to be able to use the serial program loading functionality via the Arduino
- npm or yarn (typically come with node.js) to install the senders dependencies

# Installation

The project comes with a number of files, whose functionality is the following:

1. `bootloader.asm` - the bootloader / micro kernel / mini os you wanna put into your ROM after assembly
2. `Receiver.ino` - Arduino source which turns the Arduino into a serial receiver / parallel converter
3. `Sender.js` - Node.js tool to read 6502 object code / programs and upload them to the 6502 via serial connection
4. `.sender_config.json` - config file for `Sender.js` (update your /dev/cu.whateverhere)
5. `package.json` - package dependencies for `Sender.js`
6. `/examples` - some example programs you can load into the RAM

## 1. Bootloader

Assemble the bootloader:

```
vasm -Fbin -dotdir -o bootloader.out bootloader.asm
```

Burn it onto the EEPROM using your TL866 programmer in conjunction with minipro (Linux, Mac) or the respective Windows GUI tool provided by XG (see above).

At this point you can install your ROM chip  onto the board and celebrate. You will not remove it from it's breadboardy socket for a while. If your 1MHz clock, RAM, keyboard and LCD are assembled already, you can switch on your 6502 computer and enjoy the main menu of **Sixty/5o2**. If the assembly is not done yet, go read [Ben's schematics](https://eater.net/6502) and finish your hardware build.

## 2. Receiver (Arduino)

- Load `Receiver.ino` into your Arduino IDE.
- Open the IDE's package library and search and install the `Base64` package by Arturo Guadalupi v0.0.1 also to be found [here](https://github.com/agdl/Base64)
- Compile the source
- Upload the program to your Arduino

## 3. Sender (node.js)

- Install the necessary npm packages via:

```
npm install
```
or
```
yarn
```
- Adjust the `tty` setting in `.sender_config.json` to match the device file which represents your connected Arduino
- **DO NOT** adjust any other value in there, as it will render the serial link unstable (more on that later)

# Usage

## Arduino Port Setup

Before you can upload a program to the 6502 through the Arduino, you need to setup additional jumper wires between the Arduino and the VIA 6522 **AS WELL** as the 6502 processor.

- You need 8 jumper wires connecting the digital output ports of the Arduino with the PORTB of the VIA 6522 (See table 1 below)
- You need 1 jumper wire connecting one digital output port of the Arduino with the IRQ line of the 6502 (See table 2 below)
- You need 1 jumper wire connecting one of the `GND` pins of the Arduino with common ground of your 6502 breadboard

**Table 1: Port Setup VIA 6522**
 
| Arduino | VIA 6522 |
|---------|----------|
|   31    |   10     |
|   33    |   11     |
|   35    |   12     |
|   37    |   13     |
|   39    |   14     |
|   41    |   15     |
|   43    |   16     |
|   45    |   17     |

If unsure, look up the pin setup of the VIA in the [official documentation](https://eater.net/datasheets/w65c22.pdf).

**Table 2: Port Setup 6502**
 
| Arduino |     6502    |
|---------|-------------|
|   53    |   4 (IRQB)  |

The pin setup of the 6502 can be found [here](https://eater.net/datasheets/w65c02s.pdf).

**Important:** Make sure, you still have the IRQB pin (PIN 4) of the 6502 tied high via a 1k Ohm resistor as per the design. The jumper cable to pin 53 of the Arduino just pulls the pin low in short pulses. The line needs to be normal _high_.

**Note:** Just one additional wire from the Arduinos power source to the 6502 board will free you of the need of any external power source. Just power your beast via USB and get rid of the power cord.

## Uploading a Program

You can now write a program in 6502 assembly language like for example the `/examples/hello_world.asm` and assemble it like so:

```
vasm -Fbin -dotdir -o /examples/hello_world.out /examples/hello_world.asm
```

**Important:** Since your programs now target RAM instead of ROM your program needs to have a different entry vector specified:

```
    .org $0200
```

More on **why $0200** later on.

To upload and run your gem onto your 6502, first start up the machine, and reset it. Using the keyboard navigate to `Load` using the _UP_ and _DOWN_ keys in the main menu. To start the uploading process hit the _RIGHT_ key which acts as `Enter` in most cases.

Now you can upload your program using the Sender.js CLI tool like so:

```
node Sender.js /examples/hello_world.out
```

The upload process will inform you, when it's done. The 6502 automatically switches back into the main menu after the upload finished.

Should you encounter any errors during upload, check the `tty` setting in `.sender_config.json` and adjust it to your Arduinos device port. In addition you can lower the transfer speed to values to 4800, 2400 or 1200 baud. Don't use values above 9600 baud, they won't work.

Navigate to the menu entry `Run` and hit the _RIGHT_ key to run your program.

**Go celebrate!** You're just running your first uploaded program directly from RAM.

**Note:** You can also use `Load & Run` to streamline the process during debugging.

**Also note:** Resetting your 6502 **DOES NOT** erase the RAM. So you can reset any time, and still `Run` your program afterwards.

**And note:** The `Sender.js` accepts two commandline parameters. If you want, you can also specify your Arduino port manually, whithout having to hardwire it in the `.sender_config.json` like so:

```
node Sender.js /examples/hello_world.out /dev/path_to_arduino_port
```

## Link against routines in ROM

This feature was added by **David Latham**. Big thank you! Since RAM is a scarse ressource and we do not use much of the ROM, you have the option to built and test routines in RAM first, and burn them into the ROM afterwards. This way you can build your very personal library of functions and extend the existing library of Sixty5o2.

In order to do so, you have to rebuild the `bootloader.asm` as follows:

```
vasm -Fbin -dotdir -L bootloader.lst bootloader.asm -o bootloader.out
```

This generates the symbol list `bootloader.lst` with the hexadecimal addresses for all routines and labels. If you scroll down to the bottom, you will find the addresses of every routine, that Sixty5o2 provides. Now you can use these addresses in a new program, that you assemble and upload to RAM.

Take a look at the example `using_rom_lib.asm` that David added to the examples folder.


## Using the Monitor

The **hex monitor** is very useful during development and debugging. It lets you inspect the whole address space, RAM and ROM. you can navigate using the _UP_ and _DOWN_ keys. The _RIGHT_ key performs a bigger jump in time and space and the _LEFT_ key returns you to the main menu. The monitor is currently read only and the keyboard debouncing is far from being good. But it works.

# Important to know - Allocated Ressources

## 1. $0200

I choose $0200 as entry vector for user land programs. Why you ask? Two reasons:

1. The adresses from `$0000 up to $00ff` are the so called zero page addresses, which allow 8 bit addressing and faster processing. Use them wisely, don't waste them, don't put program code in here.
2. The adresses from `$0100 up to $01ff` are used by the 6502 as stack. You better don't mess with it, because not only does it hold values after any stack push operation (like pha), but the 6502 also stores return addresses here, when performing a jump to subroutine / return from subroutine (jsr/rts).

Therefore RAM is usable in a meaningful fashion from $0200 upwards only.

**Note:** Due to Ben's (IMO clever) design choice RAM ends already at $3fff, which leaves you with close to 16kByte of RAM for your programs. Should you hit that wall, there's always the option to outsource routines as "standard library", put them onto the ROM and link them from your programs via the VASM linker.

## 2. Used Zero Page Locations

The bootloader needs to use some Zero Page locations: `$00 - $05`. Expect trouble if you overwrite / use them from within your own programs.

## 3. Used RAM

The bootloader also occupies some RAM. Most part is used as VideoRam to talk to the LCD (consult the source). [In contrast to C64 design there is no interrupt driven scanline routine that updates the LCD automatically from the VideoRam contents yet. A feature to come.] Another few RAM cells are used by the bootloader itself.

**However, don't use RAM from `$3fda upto $3fff`. Expect problems if you do so.**

## 4. Interrupt Service Routine - ISR

The Interrupt Service Routine (ISR) implemented at the end of available ROM realizes the serial loading. The way it works is quite simple. As soon as the Arduino set up all 8 bit of a byte at the data ports, it pulls the interrupt pin of the 6502 low for 30 microseconds. This triggers the 6502 to halt the current program, put all registers onto the stack and execute any routine who's starting address can be found in the Interrupt Vector Address (`$fffe-$ffff`) - the ISR. This routine reads the byte, writes it into the RAM, increases the address pointer for the next byte to come and informs the main program that data is still flowing. Consult the source for further details, it's quite straight forward.

## 5. Interrupt Service Routine Handler - ISR_SERVICE

The routine pointed to by vector address $fffe is actually the ISR_SERVICE routine.  This routine performs a zero page addressed jump `JMP $(ISR_LOC)` which is configured in bootloader.asm to point to the address of ISR.

User programs are able to overwrite the address stored in ISR_LOC to create their own interrupt routines for IRQ.  NMI is not supported yet.

For example:

``` asm
ISR_LOC 	= $04 ; uses 2 bytes ($04 and $05)
counter     = $01
	.org $0200

	lda #<CUSTOM_ISR	; set up CUSTOM ISR pointer in Zero Page
	sta ISR_LOC			; $04 LSB
	lda #>CUSTOM_ISR
	sta ISR_LOC + 1		; $05 MSB

; your program here
	lda #$00			; init 16 bit counter variable
	sta counter
	sta counter + 1

CUSTOM_ISR:
	inc counter
	bne .end_isr
	inc counter+1
.end_isr
	rti

```

A complete example of how the Ben Eater Interrupt routine that increments a counter on each button push is included in `examples/irq.asm`.  This example is designed to work with the following wiring on Ben Eater's 6502 build.

PUSH BUTTON:

* right leg tied to GROUND, left leg pulled up with 1kohm resistor to 5v.
* Left leg wired to CA1 (pin 40) on the VIA 65C22

IRQ from 65C22 (PIN 21) to IRQ on 65C02 (PIN 4).  Leave PIN 4 tied high with a 1kohm resistor.

# Shortcomings

- The loader is slow. Quite slow. Even though 9600 baud as choosen transfer speed is not too bad, there are some significant idle timeouts implemented, to make the data transfer work reliably. You'll find it in `Receiver.ino`, the `Sender.js` does not have any timeouts left other than the necessary but unproblematic connection timeout once at the beginning. The worst is the timeout which allows to reliably read the UART buffer of the Arduino. When reduced, the whole data transfer becomes unreliable.
Happy to accept PR's with improvement here. On the other hands, it's not that we transfer Gigabytes of data here ... not even Megabytes, so the current speed might suffice.

# Known Problems

Despite the fact that the bootloader and all of it's components are quite stable, there are some problems, which are to be found via a #TODO in the source.

Worth mentioning are the following:

- sub par keyboard debouncing simply via burning CPU cycles
- LIB__sleep based EOF detection during data transfer - if more than a few packages fail to transfer and need to be repeated by the sender, it might happen, that the `BOOTLOADER__program_ram` routine interprets this as EOF, since no data is coming in no more. This problem can not be "easily" solved, since there are no control characters that can be transferred between the Arduino and the 6522. There are solutions, but first there needs to be a problem.
- sub optimal register preservation - the (reduced) 6502 instruction set makes it hard to preserve all registers w/o wasting RAM locations. The current implementation does put focus on register preservation only where explicitly needed.
- the ISR is currently static, so it can handle only interrupt requests which come from the Arduino. If you want to use other interrupts of the 6522 or software interrupts, you need to implement a priorization mechanism as well as a branching in the ISR, since (to my knowledge) there is only one interrupt vector, the 6502 can handle.

# Future Plans

- make Hex Monitor read / write
- integrate Arduino Nano directly onto the board to replace all jumper wiring and power the board via USB
- develop a standard library with useful functionality in ROM
- (potentially) integrate a light color / bitmap display like for example the [Adafruit 0.96" 160x80 Color TFT Display](https://www.adafruit.com/product/3533)
- implement a 3d engine using vector rotation and scalar multiplication (or quaternions)

# Pull Requests

If you would like to see any particular feature I might be able to provide it ... some day. Unfortunately my spare time is very limited, so you rather develop it yourself. I am happy to screen, test and merge any valuable PR.

# Support

My friend and founding partner Bastian and I decided, it's time to bring all the joy and fun that come with 8bit projects to a much broader audience. I quit a well paying contract and we both ditched a number of projects, to be able to focus on 8bit related content solely.

We are currently working on a number of screencasts covering topics like:

- **The worlds worst transistor clock implemented in Logisim**
- **An 8bit computer implementation from scratch - in Logisim**
- **Architecture updates to the 8bit machine for 64kb of RAM, more registers and instructions**
- **A Ruby based assembler for homebrew 8bit projects in just a few lines of code**

... and we have numerous ideas for other, fresh content to come.

If you actually want to support us, it would mean the world to us, if you joined our newsletter. [8bitnews.io](https://8bitnews.io) is the first real 8bit newsletter out there. On a regular basis we handcraft the __latest 8bit news__, __learning resources__ and the __best YouTube videos__ into an email, and deliver it to your inbox, when you have the time for tinkering. It's well selected and curated, and we personally guarantee, there will be no spam.

[![8bitnews.io](/img/8bitnews.png)](https://8bitnews.io)

By the way, there is no catch here, you can unsubscribe with a single click. Anytime. We won't be mad at you.

# Contact

I personally really enjoy talking to likeminded people. So if you want to share your thoughts regarding this project, other 8bit topics, our newsletter or our screencasts, feel free to drop me some lines [via Email](mailto:jan@8bitnews.io) any time.

# Credits

- Ben Eater
- Steven Wozniak
- Anke L.
- Tim Miller (special thx)
- P.A. Bäckström
- Wilgert Velinga
- Ed Gleys
- Jonathan Shockley
