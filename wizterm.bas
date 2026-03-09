' Simple terminal program in SuperBASIC for the
' Wildbits/K2 and JR2 Retro computers.         
' It sends AT commands to the WizNET WiFi      
' module and displays the responses.           


WIZ_CTRL = $dd80    'Sets the control register for the terminal interface
WIZ_DATA = $dd81    'data in and out to the WizNET module                
WIZ_FIFO = $dd82    'status register to check stack                      
stack = $b0

mlcode()    'assembly for reading from the WizNET FIFO

poke $b2,0
pokew stack,$7800
stackread = $7800

poke WIZ_CTRL,$00   'Initialize the control register
'readstack()

' intialize the terminal by sending the AT commands from the 
' data statements drop down to the terminal once the commands
' have been sent. There is no error handling in this code.   
repeat
    read a$
    if a$<>"stop"
        readstack()
        for n=1 to len(a$)
            b=asc(mid$(a$,n,1))
            if b=39 then b=34
            poke WIZ_DATA,b
        next
        poke WIZ_DATA,$0d
        poke WIZ_DATA,$0a
        for n=0 to 20000:next
        readstack()
    endif
until a$="stop"
print "Done"


' The terminal interface is active. We are looping and checking for 
' data from Wiznet as well as the keyboard. $680 is the keyboard
' status register.
repeat
    call $7700
    if stackread <> peekw(stack) then readone()
    if peek($680)<>0 then readkeyboard()
until k=255


end
proc readkeyboard()
    send$="AT+CIPSEND=1"+chr$(13)+chr$(10)
    for s=1 to 14
        poke WIZ_DATA,asc(mid$(send$,s,1))
    next
    while peek(wiznet_fifo)<>0
        while j<>62
            j=peek(WIZ_DATA)
        wend
    k=inkey()
    poke WIZ_DATA,k
endproc

proc readone()
    print chr$(peek(stackread));
    stackread=stackread+1
    if stackread>=$7fff then stackread=$7800
endproc

proc readstack()
    state=0
    while peek(WIZ_FIFO)<>0
        o=peek(WIZ_DATA)
        print chr$(o);
        if (prev=79) & (o=75) then state=1
        prev=o
    wend
    poke $b2,state
endproc

proc mlcode()
    for pass=0 to 1
        assemble $7700,pass
        ' Check if there is data in the FIFO           
        ' If there is, read and store it in the buffer,
        ' and update the buffer pointer.               
        ' if no datais available, return to BASIC.     
        .start
            lda $dd82          
            bne read_buffer   
            rts     
        'read a byte from the FIFO and store it in the buffer
        .read_buffer
            lda $dd81          
            sta ($b0)         
        'incrment the buffer pointer
            clc              
            lda $b0
            adc #$01
            sta $b0
            lda $b1
            adc #$00
            sta $b1            
        ' compair pointer to the end of the buffer              
        ' and reset to the beginning if we have reached the end.
            cmp #$80           
            bcc start                    
            stz $b0
            lda #$78
            sta $b1
            bra start        
    next
endproc


data "AT+RST"
data "AT+GMR"
data "AT+UART_CUR?"
data "AT+CWMODE_CUR=1"
data "AT+CWMODE_CUR?"
data "AT+CIPMUX=0"
data "AT+CWJAP_CUR='Defiance','CorvairCorsa'"
data "AT+CWJAP_CUR?"
data "AT+CIPSTA_CUR?"
data "AT+CIPSTART='TCP','192.168.17.54',8119"
data "stop"
