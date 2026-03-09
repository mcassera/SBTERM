; WizNET buffer extractions for SBTERM


.cpu  "65816"



WCTRL = $dd80
WDATA = $dd81
WFIFO = $dd82

BUFFER = $7800
BUFFER_SIZE = $7ff
BUFFER_POINTER = $b0    ;2 bytes to indicate the next write position in the buffer
BUFFER_LENGTH = $b2     ;2 bytes to indicate the current length of loaded data in the buffer



* = $7700
start:

    lda WFIFO
    bne Read_Buffer
    rts

Read_Buffer:
    ;Read the next byte from the DATA and store it in the buffer
    lda WDATA
    sta (BUFFER_POINTER)
    ;Increment the buffer pointer
    clc
    lda BUFFER_POINTER
    adc #$01
    sta BUFFER_POINTER
    lda BUFFER_POINTER+1
    adc #$00
    sta BUFFER_POINTER+1
    cmp #$80
    bcc Increase_length
    ;If the buffer pointer exceeds the buffer size, wrap around to the beginning
    lda #<BUFFER
    sta BUFFER_POINTER
    lda #>BUFFER
    sta BUFFER_POINTER+1
    
Increase_length:
    ;Increment the buffer length
    clc
    lda BUFFER_LENGTH
    adc #$01
    sta BUFFER_LENGTH
    lda BUFFER_LENGTH+1
    adc #$00
    sta BUFFER_LENGTH+1

    bra start
