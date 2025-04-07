from machine import SPI, Pin
from pyb import delay
import binascii

# SD Commands
GO_IDLE_STATE     = CMD0   = 0
SEND_IF_COND      = CMD8   = 8
READ_OCR          = CMD58  = 58
READ_SINGLE_BLOCK = CMD17  = 17
APP_CMD           = CMD55  = 55
SD_SEND_OP_COND   = ACMD41 = 41

# Chip Select
cs = Pin('PB12', Pin.OUT)


# SPI Bus
bus = SPI(1)

# SPI layer methods
def spi_transfer(data):
    bus.write(data)

def spi_read(length):
    return bus.read(length, 0xFF)
    
def chip_select():
    cs.low()
    
def chip_deselect():
    cs.high()
    
def spi_init():
    bus.init(baudrate=100000, polarity=0, phase=0)
    print(bus) # to show actual bus speed
    
# SD layer methods

# object with buffer protocol required
# i.e. can't use a number
def sd_frame(command, arg, crc):
    frame = bytearray([
        (0 << 7 | 1 << 6 | command), # Start bit, Transmission (Host sending) bit, Command index
        (arg >> 24) & 0xFF, # Argument bits
        (arg >> 16) & 0xFF,
        (arg >> 08) & 0xFF,
        (arg >> 00) & 0xFF,
        (crc << 1) |  0x01, # CRC and the Stop bit
    ])
    
    return frame

def sd_transfer(command, arg, crc, nresponse):
    frame = sd_frame(command, arg, crc)
    print(binascii.hexlify(frame))
    response = None
    
    chip_select()
    
    spi_transfer(frame)
    
    for _ in range(10): # wait for R1 response (1 byte long), timeout otherwise
        response = spi_read(1)
        print(response)
        
        # sd card responded
        if (response[0] & 0x10 == 0):
            result = None
            
            # error check
            if response[0] & 0x04:
                print("Illegal Command!")
            elif response[0] & 0x08:
                print("CRC Error!")
            elif response[0] & 0x10:
                print("Erase sequence error!")
            elif response[0] & 0x20:
                print("Address error!")
            elif response[0] & 0x40:
                print("Parameter error!")
                
            if response[0] & 0xFE != 0:
                chip_deselect()
                spi_transfer(b'\xFFFF')
                #print(response)
                return (-1, None)
                
            if nresponse:
                result = spi_read(nresponse)
                print(result)
                
            chip_deselect()
            spi_transfer(b'\xFFFF')
            return (0, result, response)    
        
    chip_deselect()
    spi_transfer(b'\xFFFF')
    #print(response)
    return (-1, None)

def sd_init():
    # give it time to spin up
    chip_deselect()
    
    spi_init()
    
    # Send dummy clocks with CS high
    for i in range(16):
        spi_transfer(b'\xFF')
            
    # 7.2.2 Bus Transfer Protection
    # Because CRC is disabled in SPI mode but enabled by defautlt in SDIO mode
    # A valid reset command is: 0x40, 0x0, 0x0, 0x0, 0x0, 0x95
    # 4.5 CRC
    # G(x) = x^7 + x^3 + 1
    # Using some online CRC calculator because I am lazy, 0x4a is the remainder
    # CS is going to be low as per SPI specification
    
    
    # attempt GO_IDLE_STATE couple of times
    result = None
    
    for _ in range(10):
        if result and result[0] >= 0:
            break
        result = sd_transfer(GO_IDLE_STATE, 0x0, 0x4A, 0)
        
    if result[0] < 0:
        print("SDCard initialization error!")
        raise SystemExit
             
    # Using some online CRC calculator because I am lazy, 0x43 is the remainder
    result = sd_transfer(SEND_IF_COND, 0x01AA, 0x43, 4)
    if result[0] < 0:
        print("SDCard interface condition error!")
        raise SystemExit
        
    result = sd_transfer(READ_OCR, 0, 0, 4)
    if result[0] < 0:
        print("SDCard READ_OCR error!")    
        
    for _ in range(100):
        result = sd_transfer(APP_CMD, 0, 0, 0)
        if result[0] < 0:
            print("SDCard APP_CMD error!")
        
        result = sd_transfer(SD_SEND_OP_COND, 0x40000000, 0, 0) # SDHC support which i don't understand
        if result[0] < 0:
            print("SDCard ACMD41 error!")
        elif result[2][0] & 0x1 != 1:
            break
        delay(100)
        
    # Card initialized
    
    

# print number in binary
# print("{:048b}".format(sd_frame(GO_IDLE_STATE, 0, 74)))

# print bytearray in hex
#print(binascii.hexlify(sd_frame(GO_IDLE_STATE, 0, 74)))

sd_init()

