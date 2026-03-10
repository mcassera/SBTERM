 100 ' Simple terminal program in SuperBASIC for the
 105 ' Wildbits/K2 and JR2 Retro computers.         
 110 ' It sends AT commands to the WizNET WiFi      
 115 ' module and displays the responses.           


 120 WIZ_CTRL = $dd80    'Sets the control register for the terminal interface
 125 WIZ_DATA = $dd81    'data in and out to the WizNET module                
 130 WIZ_FIFO = $dd82    'status register to check stack     
 135 stackread = $7800                 
 140 stack = $b0
 145 stackread = $b2
 150 read_buffer = alloc(40)
 155 send_key = alloc(256)

 160 print chr$(144) 'set background to black
 165 print chr$(131) 'set foreground to green
 170 cls

 175 mlcode(read_buffer)    'assembly for reading from the WizNET FIFO
 180 sendmlcode(send_key)          'assembly for sending keyboard input to the WizNET module

 185 pokew stack,$7800
 190 pokew stackread,$7800
 195 poke $b5,0          'reset the state machine for parsing IPD
 200 pokew $b6,0         'reset the payload length counter
 205 poke WIZ_CTRL,$00   'Initialize the WizNET control register

 210 initialize(stackread,read_buffer)    ' initialize the WizNET module
 215 connect()       ' Connect to the WiFi network
 220 'server()        ' Connect to the server


 225 ' The terminal interface is active. We are looping and checking for 
 230 ' data from Wiznet as well as the keyboard. $680 is the keyboard
 235 ' status register.
 240 repeat
 245     clcon=0
 250     repeat
 255         call read_buffer
 260         if peekw(stackread) <> peekw(stack) then readterm()
 265         if peek($680)<>0 
 270             k=inkey()
 275             if k=129
 280                 disconnect()
 285                 end
 290             else
 295                 poke $cf,k
 300                 call send_key
 305             endif
 310         endif
 315         clcon=clcon+1
 320     until clcon=100
 325     readstack()
 330     checkresponse()
 335 until peek($b4)=4
 340 print "Connection closed by server"
 345 end

 350 proc initialize(stackread,read_buffer)
 355     ' setup up memory for keyboard send. 
 360     ' store string starting at $c0 and then use the assembly
 365     ' routine to send it to the WizNET module.
 370     send$="AT+CIPSEND=1"+chr$(13)+chr$(10)
 375     for s=1 to len(send$)
 380         poke $bf+s,asc(mid$(send$,s,1))
 385     next
 390     ' intialize the terminal by sending the AT commands from the 
 395     ' data statements drop down to the terminal once the commands
 400     ' have been sent. There is no error handling in this code.   
 405     repeat
 410         read a$
 415         if a$<>"stop"
 420             sendcommand(a$)
 425             for n=0 to 10000:next
 430             call read_buffer
 435             readstack()
 440             checkresponse()
 445         endif
 450     until a$="stop"
 455 endproc

 460 proc sendcommand(a$)
 465     ' Send an AT command to the WizNET module by writing
 470     ' each character to the WIZ_DATA register, followed 
 475     ' by a carriage return and line feed.
 480     for n=1 to len(a$)
 485         b=asc(mid$(a$,n,1))
 490         if b=39 then b=34
 495         poke WIZ_DATA,b
 500     next
 505     poke WIZ_DATA,$0d
 510     poke WIZ_DATA,$0a
 515 endproc

 520 proc checkresponse()
 525     ' Check the response from the WizNET module after
 530     ' sending each AT command         
 535     check=peekw($b0)  
 540     rsp$=""  
 545     for n=check-10 to check-1
 550         rsp$=rsp$+chr$(peek(n))
 555     next
 560     if mid$(rsp$,7,2)="OK" then poke $b4,1
 565     if mid$(rsp$,4,5)="ERROR" then poke $b4,2
 570     if mid$(rsp$,5,4)="FAIL" then poke $b4,3
 575     if mid$(rsp$,3,6)="CLOSED" then poke $b4,4
 580 endproc

 585 proc connect()
 590     ' Connect to the WiFi network by sending the appropriate
 595     ' AT commands to the WizNET module. The code waits for a
 600     ' response after each command and checks if the connection
 605     ' was successful.
 610     read a$
 615     sendcommand(a$)
 620     for n=0 to 5000:next
 625     call read_buffer
 630     readstack()
 635     poke $b4,0
 640     while peek($b4)<>1
 645         for n=0 to 20000:next
 650         call read_buffer
 655         readstack()
 660         checkresponse()
 665         if peek($b4)=3 
 670             print "Failed to connect to WiFi network"
 675             stop
 680         endif
 685     wend
 690     read a$
 695     sendcommand(a$)
 700     for n=0 to 20000:next
 705     call read_buffer
 710     readstack()
 715     read a$
 720     sendcommand(a$)
 725     for n=0 to 20000:next
 730     call read_buffer
 735 endproc 

 740 proc readstack()
 745     ' Drain buffered bytes by routing each one through readterm.
 750     while peekw($b2) <> peekw($b0) 
 755         readterm()
 760     wend
 765 endproc

 770 proc readone()
 775     ' Print one buffered byte and advance the read pointer.
 780     print chr$(peek(peekw($b2)));
 785     pokew $b2, peekw($b2)+1
 790     if peekw($b2)>=$7fff then pokew $b2,$7800
 795 endproc

 800 proc readterm()
 805     ' Handle one incoming byte as payload data or parser input.
 810     t$= chr$(peek(peekw($b2)))
 815     st=peek($b5)
 820     if st=6
 825         print t$;
 830         rm=peekw($b6)-1
 835         pokew $b6,rm
 840         if rm<=0
 845             poke $b5,0
 850             pokew $b6,0
 855         endif
 860     else
 865         checkipd()
 870     endif
 875     pokew $b2, peekw($b2)+1
 880     if peekw($b2)>=$7fff then pokew $b2,$7800
 885 endproc

 890 proc printpayload()
 895     ' Output the currently tracked payload byte count.
 900     for n=1 to peek($b6)
 905         readone()
 910     next
 915 endproc

 920 proc checkipd()
 925     ' Parse +IPD framing and print non-payload status characters.
 930     st=peek($b5)
 935     rm=peekw($b6)

 940     if st=0
 945         if t$="+"
 950             poke $b5,1
 955         else
 960             print t$;
 965         endif
 970     endif

 975     if st=1
 980         if t$="I"
 985             poke $b5,2
 990         else
 995             print "+";
1000             if t$="+"
1005                 poke $b5,1
1010             else
1015                 print t$;
1020                 poke $b5,0
1025             endif
1030         endif
1035     endif

1040     if st=2
1045         if t$="P"
1050             poke $b5,3
1055         else
1060             print "+I";
1065             if t$="+"
1070                 poke $b5,1
1075             else
1080                 print t$;
1085                 poke $b5,0
1090             endif
1095         endif
1100     endif

1105     if st=3
1110         if t$="D"
1115             poke $b5,4
1120         else
1125             print "+IP";
1130             if t$="+"
1135                 poke $b5,1
1140             else
1145                 print t$;
1150                 poke $b5,0
1155             endif
1160         endif
1165     endif

1170     if st=4
1175         if t$=","
1180             pokew $b6,0
1185             poke $b5,5
1190         else
1195             print "+IPD";
1200             if t$="+"
1205                 poke $b5,1
1210             else
1215                 print t$;
1220                 poke $b5,0
1225             endif
1230         endif
1235     endif

1240     if st=5
1245         ch=asc(t$)
1250         if (ch>=48) & (ch<=57)
1255             rm=(rm*10)+(ch-48)
1260             pokew $b6,rm
1265         else
1270             if (t$=":") & (rm>0)
1275                 poke $b5,6
1280             else
1285                 print "+IPD,";
1290                 print str$(rm);
1295                 print t$;
1300                 poke $b5,0
1305                 pokew $b6,0
1310             endif
1315         endif
1320     endif

1325     if (st<>0) & (st<>1) & (st<>2) & (st<>3) & (st<>4) & (st<>5)
1330         poke $b5,0
1335         pokew $b6,0
1340         print t$;
1345     endif
1350 endproc

1355 proc disconnect()
1360     ' Send the AT command to disconnect from the server, and then
1365     ' reset the WizNET module.
1370     send$="AT+CIPCLOSE"+chr$(13)+chr$(10)
1375     for s=1 to len(send$)
1380         poke WIZ_DATA,asc(mid$(send$,s,1))
1385     next
1390     readstack()
1395     for n=0 to 20000:next
1400     send$="AT+RST"+chr$(13)+chr$(10)
1405     for s=1 to len(send$)
1410         poke WIZ_DATA,asc(mid$(send$,s,1))
1415     next
1420     readstack()
1425     print"Disconnected from server"
1430 endproc

1435 proc sendmlcode(send_key)
1440     ' Assemble keyboard-send helper with 
1445     ' prompt wait and chatter trim.     
1450     for pass=0 to 1
1455         assemble send_key,pass
1460         .st
1465         ' grab that key from the buffer to send to the 
1470         ' wiznet module, and then return to BASIC.
1475             ldx #$00
1480         .loopx
1485             lda $c0,x
1490             sta WIZ_DATA
1495             inx
1500             cpx #$0e
1505             bcc loopx
1510         .wait
1515             jsr read_buffer
1520             lda $b1
1525             cmp $b3
1530             beq chklo
1535             bra chkforprompt
1540         .chklo
1545             lda $b0
1550             cmp $b2
1555             beq wait
1560         .chkforprompt
1565             lda ($b2)
1570             cmp #62
1575             beq send_key2
1580         .nextchar
1585             clc
1590             lda $b2
1595             adc #1
1600             sta $b2
1605             lda $b3
1610             adc #0
1615             sta $b3
1620             cmp #$80
1625             bcc wait
1630             stz $b2
1635             lda #$78
1640             sta $b3
1645             bra wait
1650         .send_key2
1655             lda $cf
1660             sta WIZ_DATA
1665             ' Consume local send acknowledgement text    
1670             ' until SEND OK is seen. This keeps Recv/SEND
1675             ' chatter out of the terminal display path.  
1680             ldx #$00
1685         .waitsendok
1690             jsr read_buffer
1695             lda $b1
1700             cmp $b3
1705             beq wchklo2
1710             bra wchkchar2
1715         .wchklo2
1720             lda $b0
1725             cmp $b2
1730             beq waitsendok
1735         .wchkchar2
1740             lda ($b2)
1745             cpx #$00
1750             bne c1
1755             cmp #83
1760             bra chkend
1765         .c1
1770             cpx #$01
1775             bne c2
1780             cmp #69
1785             bra chkend
1790         .c2
1795             cpx #$02
1800             bne c3
1805             cmp #78
1810             bra chkend
1815         .c3
1820             cpx #$03
1825             bne c4
1830             cmp #68
1835             bra chkend
1840         .c4
1845             cpx #$04
1850             bne c5
1855             cmp #32
1860             bra chkend
1865         .c5
1870             cpx #$05
1875             bne c6
1880             cmp #79
1885             bra chkend
1890         .c6
1895             cmp #75
1900         .chkend
1905             bne nomatch
1910             inx
1915             cpx #$07
1920             bcc advancebuf
1925             ' Eat trailing CR/LF that follows SEND OK.
1930             jsr advread
1935             ldx #$20
1940         .trimlf
1945             jsr read_buffer
1950             lda $b1
1955             cmp $b3
1960             beq trimidle
1965             bra trimchar
1970         .trimidle
1975             lda $b0
1980             cmp $b2
1985             bne trimchar
1990             dex
1995             bne trimlf
2000             bra done_send
2005         .trimchar
2010             ldx #$20
2015             lda ($b2)
2020             cmp #$0d
2025             beq trimnext
2030             cmp #$0a
2035             beq trimnext
2040             bra done_send
2045         .trimnext
2050             jsr advread
2055             bra trimlf
2060         .done_send
2065             rts
2070         .nomatch
2075             lda ($b2)
2080             cmp #83
2085             bne resetidx
2090             ldx #$01
2095             bra advancebuf
2100         .resetidx
2105             ldx #$00
2110         .advancebuf
2115             jsr advread
2120             jmp waitsendok

2125         .advread
2130             clc
2135             lda $b2
2140             adc #1
2145             sta $b2
2150             lda $b3
2155             adc #0
2160             sta $b3
2165             cmp #$80
2170             bcc advdone
2175             stz $b2
2180             lda #$78
2185             sta $b3
2190         .advdone
2195             rts
2200     next
2205 endproc


        
2210 proc mlcode(read_buffer)
2215     ' Assemble FIFO reader that pushes bytes into circular buffer.
2220     for pass=0 to 1
2225         assemble read_buffer,pass
2230         ' Check if there is data in the FIFO           
2235         ' If there is, read and store it in the buffer,
2240         ' and update the buffer pointer.               
2245         ' if no datais available, return to BASIC.     
2250         .start
2255             lda $dd82          'Wiznet FIFO status register
2260             bne read_wiznet 
2265             rts     
2270         'read a byte from the FIFO and store it in the buffer
2275         .read_wiznet
2280             lda $dd81          'Wiznet data register
2285             sta ($b0)         
2290         'incrment the buffer pointer
2295             clc              
2300             lda $b0
2305             adc #$01
2310             sta $b0
2315             lda $b1
2320             adc #$00
2325             sta $b1            
2330         ' compair pointer to the end of the buffer              
2335         ' and reset to the beginning if we have reached the end.
2340             cmp #$80           
2345             bcc start                    
2350             stz $b0
2355             lda #$78
2360             sta $b1
2365             bra start        
2370     next
2375 endproc

2380 ' initialize the WizNET chip with these AT commands
2385 data "AT+GMR"
2390 data "AT+UART_CUR?"
2395 data "AT+CWMODE_CUR=1"
2400 data "AT+CWMODE_CUR?"
2405 data "AT+CIPMUX=0"
2410 data "stop"

2415 ' connect to the wifi network
2420 data "AT+CWJAP_CUR='SSID','PASSWORD'"
2425 data "AT+CIPSTA_CUR?"

2430 ' connect to the server
2435 data "AT+CIPSTART='TCP','BBS_ADDRESS',PORT"
